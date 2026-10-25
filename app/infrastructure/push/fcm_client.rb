# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Push
  class FcmClient
    class Error < StandardError; end
    class Unregistered < Error; end

    TOKEN_URI   = URI("https://oauth2.googleapis.com/token")
    SCOPE       = "https://www.googleapis.com/auth/firebase.messaging"
    CACHE_KEY   = "push:fcm:access_token"
    TOKEN_TTL   = 55.minutes
    CHANNEL_ID  = "findu_default"
    UNREGISTERED_CODES = %w[UNREGISTERED INVALID_ARGUMENT].freeze

    def self.configured?
      ENV["FCM_SERVICE_ACCOUNT_JSON"].present?
    end

    def initialize(service_account: ENV.fetch("FCM_SERVICE_ACCOUNT_JSON"))
      @account = JSON.parse(service_account)
    end

    def send_to_token(token:, title:, body:, data: {})
      payload = {
        message: {
          token:        token,
          notification: { title: title, body: body }.compact,
          data:         data.transform_keys(&:to_s).transform_values(&:to_s),
          android:      { priority: "high", notification: { channel_id: CHANNEL_ID } }
        }
      }
      response = post_json(messages_uri, payload, bearer: access_token)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      raise_for(response)
    end

    private

    def messages_uri
      URI("https://fcm.googleapis.com/v1/projects/#{@account.fetch('project_id')}/messages:send")
    end

    def access_token
      Rails.cache.fetch(CACHE_KEY, expires_in: TOKEN_TTL) { request_access_token }
    end

    def request_access_token
      now = Time.now.to_i
      claims = {
        iss:   @account.fetch("client_email"),
        scope: SCOPE,
        aud:   TOKEN_URI.to_s,
        iat:   now,
        exp:   now + 3600
      }
      assertion = JWT.encode(claims, OpenSSL::PKey::RSA.new(@account.fetch("private_key")), "RS256")

      response = Net::HTTP.post_form(TOKEN_URI, grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion)
      raise Error, "oauth #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("access_token")
    end

    def post_json(uri, payload, bearer:)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{bearer}"
      request["Content-Type"]  = "application/json"
      request.body = JSON.generate(payload)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end
    end

    def raise_for(response)
      body    = JSON.parse(response.body) rescue {}
      details = Array(body.dig("error", "details"))
      code    = details.filter_map { |d| d["errorCode"] }.first || body.dig("error", "status")

      raise Unregistered, code if UNREGISTERED_CODES.include?(code)
      raise Error, "fcm #{response.code}: #{code || response.body}"
    end
  end
end
