# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after { Rack::Attack.enabled = false }

  def post_login(email:, password: "wrong-password", ip: "203.0.113.10")
    post "/api/v1/login",
         params:  { user: { email: email, password: password } }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => ip }
  end

  describe "POST /api/v1/login" do
    let(:email) { "victim@example.com" }

    it "throttles by email even when the attacker rotates the source IP" do
      5.times { |i| post_login(email: email, ip: "198.51.100.#{i}") }

      expect(response).not_to have_http_status(:too_many_requests)

      post_login(email: email, ip: "198.51.100.200")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "keys the email counter case- and whitespace-insensitively" do
      5.times { |i| post_login(email: email, ip: "198.51.100.#{i}") }

      post_login(email: "  VICTIM@Example.com ", ip: "198.51.100.201")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "does not throttle a different account" do
      5.times { |i| post_login(email: email, ip: "198.51.100.#{i}") }

      post_login(email: "someone-else@example.com", ip: "198.51.100.202")

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "throttles by IP when the attacker sprays many accounts" do
      20.times { |i| post_login(email: "user#{i}@example.com", ip: "203.0.113.99") }

      post_login(email: "another@example.com", ip: "203.0.113.99")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "answers throttled requests in the standard API error envelope" do
      6.times { |i| post_login(email: email, ip: "198.51.100.#{i}") }

      body = JSON.parse(response.body)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq(20.minutes.to_i.to_s)
      expect(body["success"]).to be(false)
      expect(body["errorCode"]).to eq(ErrorMapper.too_many_requests.code)
    end
  end

  describe "POST /api/v1/user" do
    it "throttles automated signups from the same IP" do
      6.times do |i|
        post "/api/v1/user",
             params:  { user: { name: "User #{i}", email: "new#{i}@example.com", password: "password123", password_confirmation: "password123" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "203.0.113.50" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "GET /health" do
    it "is safelisted so the platform health check is never throttled" do
      400.times { get "/health", headers: { "REMOTE_ADDR" => "203.0.113.77" } }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /rails/active_storage/direct_uploads" do
    it "is blocked so anonymous clients cannot create blobs in the bucket" do
      post "/rails/active_storage/direct_uploads",
           params:  { blob: { filename: "x.png", byte_size: 1, checksum: "abc", content_type: "image/png" } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "203.0.113.60" }

      body = JSON.parse(response.body)

      expect(response).to have_http_status(:forbidden)
      expect(body["success"]).to be(false)
    end
  end

  describe "routes outside /api" do
    it "throttles them too, so the limit is not bypassed by the engine routes" do
      301.times do
        get "/users/password/edit", headers: { "REMOTE_ADDR" => "203.0.113.90" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
