# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session tokens", type: :request do
  let(:password) { "password123" }
  let!(:user)    { create(:user, password: password, password_confirmation: password) }
  let(:headers)  { { "CONTENT_TYPE" => "application/json", "X-Client-Platform" => "web" } }

  # Não memoizado: cada request tem um corpo diferente.
  def json
    JSON.parse(response.body)
  end

  def login
    post "/api/v1/login",
         params:  { user: { email: user.email, password: password } }.to_json,
         headers: headers
  end

  describe "POST /api/v1/login" do
    it "returns an access token header and a refresh token" do
      login

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to start_with("Bearer ")
      expect(json.dig("data", "refresh_token")).to be_present
      expect(user.refresh_tokens.active.count).to eq(1)
      expect(user.refresh_tokens.first.client).to eq("web")
    end
  end

  describe "POST /api/v1/user" do
    it "returns a refresh token on signup" do
      post "/api/v1/user",
           params:  { user: { name: "Novo", email: "novo@example.com", password: password, password_confirmation: password } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response.headers["Authorization"]).to start_with("Bearer ")
      expect(json.dig("data", "refresh_token")).to be_present
    end
  end

  describe "POST /api/v1/token/refresh" do
    it "rotates the refresh token and issues a new access token usable on protected routes" do
      login
      old_refresh = json.dig("data", "refresh_token")
      old_access  = response.headers["Authorization"]

      post "/api/v1/token/refresh", params: { refresh_token: old_refresh }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      new_access  = response.headers["Authorization"]
      new_refresh = json.dig("data", "refresh_token")
      expect(new_access).to start_with("Bearer ")
      expect(new_refresh).to be_present
      expect(new_refresh).not_to eq(old_refresh)
      expect(json.dig("data", "user", "id")).to eq(user.id)

      get "/api/v1/user", headers: { "Authorization" => new_access }
      expect(response).to have_http_status(:ok)

      # access token antigo continua válido até expirar (mesmo jti)
      get "/api/v1/user", headers: { "Authorization" => old_access }
      expect(response).to have_http_status(:ok)
    end

    it "returns 401 for an invalid token" do
      post "/api/v1/token/refresh", params: { refresh_token: "garbage" }.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(json["success"]).to be(false)
    end

    it "returns 401 and revokes the family when a used token is replayed" do
      login
      first = json.dig("data", "refresh_token")

      post "/api/v1/token/refresh", params: { refresh_token: first }.to_json, headers: headers
      second = json.dig("data", "refresh_token")

      post "/api/v1/token/refresh", params: { refresh_token: first }.to_json, headers: headers
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/token/refresh", params: { refresh_token: second }.to_json, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 400 when the token is missing" do
      post "/api/v1/token/refresh", params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/v1/logout" do
    it "revokes the refresh token family sent in the body" do
      login
      refresh = json.dig("data", "refresh_token")
      access  = response.headers["Authorization"]

      delete "/api/v1/logout",
             params:  { refresh_token: refresh }.to_json,
             headers: headers.merge("Authorization" => access)

      expect(response).to have_http_status(:ok)
      expect(user.refresh_tokens.active).to be_empty

      post "/api/v1/token/refresh", params: { refresh_token: refresh }.to_json, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
