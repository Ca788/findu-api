# frozen_string_literal: true

Rack::Attack.enabled =
  if Rails.env.test?
    ENV["RACK_ATTACK_ENABLED"] == "true"
  else
    ENV.fetch("RACK_ATTACK_ENABLED", "true") == "true"
  end

cache_store = Rails.cache
cache_store = ActiveSupport::Cache::MemoryStore.new if cache_store.is_a?(ActiveSupport::Cache::NullStore)
Rack::Attack.cache.store = cache_store

class Rack::Attack
  LOGIN_PATH           = "/api/v1/login"
  SIGNUP_PATH          = "/api/v1/user"
  PASSWORD_RESET_PATH  = "/api/v1/password"
  DIRECT_UPLOADS_PATH  = "/rails/active_storage/direct_uploads"

  MAX_INSPECTED_BODY_BYTES = 8.kilobytes

  class Request < ::Rack::Request
    def client_ip
      env["action_dispatch.remote_ip"]&.to_s.presence || ip
    end

    def auth_email
      return @auth_email if defined?(@auth_email)

      @auth_email = extract_auth_email
    end

    private

    def extract_auth_email
      return nil unless media_type == "application/json"
      return nil if content_length.to_i > MAX_INSPECTED_BODY_BYTES

      raw = begin
        body.rewind
        body.read
      ensure
        body.rewind
      end

      JSON.parse(raw.to_s).dig("user", "email").to_s.downcase.strip.presence
    rescue JSON::ParserError, TypeError, NoMethodError
      nil
    end
  end

  safelist("health check") { |req| req.path == "/health" }

  blocklist("active storage direct uploads") do |req|
    req.path == DIRECT_UPLOADS_PATH
  end

  throttle("general/ip", limit: 300, period: 1.minute, &:client_ip)

  throttle("login/email", limit: 5, period: 20.minutes) do |req|
    req.auth_email if req.post? && req.path == LOGIN_PATH
  end

  throttle("login/ip", limit: 20, period: 5.minutes) do |req|
    req.client_ip if req.post? && req.path == LOGIN_PATH
  end

  throttle("password_reset/email", limit: 3, period: 1.hour) do |req|
    req.auth_email if req.post? && req.path == PASSWORD_RESET_PATH
  end

  throttle("password_reset/ip", limit: 10, period: 1.hour) do |req|
    req.client_ip if req.post? && req.path == PASSWORD_RESET_PATH
  end

  throttle("password_update/ip", limit: 10, period: 1.hour) do |req|
    req.client_ip if req.patch? && req.path == PASSWORD_RESET_PATH
  end

  throttle("signup/ip", limit: 5, period: 1.hour) do |req|
    req.client_ip if req.post? && req.path == SIGNUP_PATH
  end

  self.blocklisted_responder = lambda do |_request|
    body = ApiResponseSerializer.render(
      {},
      success:    false,
      message:    "Endpoint disabled.",
      error_code: ErrorMapper.unauthorized.code
    )

    [403, { "Content-Type" => "application/json" }, [body]]
  end

  self.throttled_responder = lambda do |request|
    match_data  = request.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period].to_i
    retry_after = 60 unless retry_after.positive?

    body = ApiResponseSerializer.render(
      {},
      success:    false,
      message:    "Too many requests. Please try again later.",
      error_code: ErrorMapper.too_many_requests.code
    )

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [body]
    ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn(
    "[rack-attack] throttled rule=#{request.env['rack.attack.matched']} " \
    "ip=#{request.client_ip} path=#{request.request_method} #{request.path}"
  )
end
