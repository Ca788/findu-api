# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Push
  class FcmClient
    class Error < StandardError; end
    class Unregistered < Error; end
    class Transient < Error; end

    TOKEN_URI   = URI("https://oauth2.googleapis.com/token")
    SCOPE       = "https://www.googleapis.com/auth/firebase.messaging"
    CACHE_KEY   = "push:fcm:access_token"
    TOKEN_TTL   = 55.minutes
    CHANNEL_ID  = "findu_default"

    TRANSIENT_CODES = %w[
      UNAVAILABLE
      INTERNAL
      UNKNOWN
      RESOURCE_EXHAUSTED
      QUOTA_EXCEEDED
      DEADLINE_EXCEEDED
      UNAUTHENTICATED
    ].freeze

    INVALID_TOKEN_PATTERN = /registration token/i

    def self.configured?
      ENV["FCM_SERVICE_ACCOUNT_JSON"].present?
    end

    def initialize(service_account: ENV.fetch("FCM_SERVICE_ACCOUNT_JSON"))
      @account = JSON.parse(service_account)
    end

    def send_to_token(token:, title:, body:, data: {}, platform: nil, collapse_key: nil)
      payload = { message: build_message(token, title, body, data, platform, collapse_key) }
      response = deliver(payload)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      raise_for(response)
    rescue JSON::ParserError => e
      raise Transient, "fcm json: #{e.message}"
    end

    private

    def build_message(token, title, body, data, platform, collapse_key)
      message = {
        token:        token,
        notification: { title: title, body: body }.compact,
        data:         data.transform_keys(&:to_s).transform_values(&:to_s)
      }
      message[:android] = android_config(collapse_key) unless %w[ios web].include?(platform.to_s)
      message
    end

    def android_config(collapse_key)
      config = { priority: "high", notification: { channel_id: CHANNEL_ID } }
      config[:collapse_key] = collapse_key.to_s if collapse_key.present?
      config
    end

    def messages_uri
      URI("https://fcm.googleapis.com/v1/projects/#{@account.fetch('project_id')}/messages:send")
    end

    def deliver(payload)
      response = post_json(messages_uri, payload, bearer: access_token)
      return response unless response.code.to_i == 401

      Rails.cache.delete(CACHE_KEY)
      post_json(messages_uri, payload, bearer: access_token)
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

      response = post_form(
        TOKEN_URI,
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion:  assertion
      )
      unless response.is_a?(Net::HTTPSuccess)
        raise Transient, "oauth #{response.code}: #{response.body}" if transient_http?(response, oauth_code(response))
        raise Error, "oauth #{response.code}: #{response.body}"
      end

      JSON.parse(response.body).fetch("access_token")
    rescue JSON::ParserError => e
      raise Transient, "oauth json: #{e.message}"
    end

    def post_form(uri, params)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params)
      http_start(uri) { |http| http.request(request) }
    end

    def post_json(uri, payload, bearer:)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{bearer}"
      request["Content-Type"]  = "application/json"
      request.body = JSON.generate(payload)

      http_start(uri) { |http| http.request(request) }
    end

    def http_start(uri, &block)
      Http::Network.start(uri, &block)
    rescue Http::Network::Error => e
      raise Transient, e.message
    end

    def raise_for(response)
      body    = JSON.parse(response.body) rescue {}
      details = Array(body.dig("error", "details"))
      code    = details.filter_map { |d| d["errorCode"] }.first || body.dig("error", "status")
      message = body.dig("error", "message").to_s

      raise Unregistered, code if unregistered?(code, message)
      raise Transient, "fcm #{response.code}: #{code || response.body}" if transient_http?(response, code)
      raise Error, "fcm #{response.code}: #{code || response.body}"
    end

    def unregistered?(code, message)
      return true if code == "UNREGISTERED"
      code == "INVALID_ARGUMENT" && message.match?(INVALID_TOKEN_PATTERN)
    end

    def transient_http?(response, code)
      return true if TRANSIENT_CODES.include?(code)
      return true if response.code.to_i == 429

      response.code.to_i >= 500
    end

    def oauth_code(response)
      body = JSON.parse(response.body) rescue {}
      body["error"] || body.dig("error", "status")
    end
  end
end
