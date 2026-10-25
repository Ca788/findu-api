# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:user)  { create(:user) }
  let(:token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
  let(:headers) do
    { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  def json
    JSON.parse(response.body)
  end

  it "lists only the current user's notifications, newest first, with unread count" do
    create(:notification, :read, user: user, created_at: 3.days.ago)
    older = create(:notification, user: user, created_at: 2.days.ago)
    newer = create(:notification, user: user, kind: "budget_warning", title: "Orçamento em 85% do limite")
    create(:notification)

    get "/api/v1/notifications", params: { per_page: 2 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"].map { |n| n["id"] }).to eq([newer.id, older.id])
    expect(json["data"].first).to include("group" => "budgets", "read" => false)
    expect(json["pagination"]).to include("totalCount" => 3, "totalPages" => 2)
    expect(json["metadata"]).to eq("unread_count" => 2)
  end

  it "filters by unread and by kind" do
    create(:notification, :read, user: user)
    unread = create(:notification, user: user, kind: "insights_ready", title: "2 novos insights")

    get "/api/v1/notifications", params: { unread: true, kind: "insights_ready" }, headers: headers

    expect(json["data"].map { |n| n["id"] }).to eq([unread.id])
  end

  it "marks one and then all notifications as read" do
    first  = create(:notification, user: user)
    second = create(:notification, user: user)
    foreign = create(:notification)

    post "/api/v1/notifications/#{first.id}/read", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]["read"]).to be(true)
    expect(second.reload.read?).to be(false)

    post "/api/v1/notifications/read_all", headers: headers
    expect(json["data"]).to eq("updated" => 1, "unread_count" => 0)
    expect(foreign.reload.read?).to be(false)

    get "/api/v1/notifications/unread_count", headers: headers
    expect(json["data"]).to eq("unread_count" => 0)
  end

  it "refuses to mark another user's notification" do
    foreign = create(:notification)

    post "/api/v1/notifications/#{foreign.id}/read", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.read?).to be(false)
  end

  it "registers, re-registers and removes device tokens scoped to the user" do
    post "/api/v1/notifications/devices", params: { token: "fcm-1", platform: "android" }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("platform" => "android")

    post "/api/v1/notifications/devices", params: { token: "fcm-1" }.to_json, headers: headers
    expect(user.device_tokens.count).to eq(1)

    other = create(:user)
    other_token = Warden::JWTAuth::UserEncoder.new.call(other, :user, nil).first
    post "/api/v1/notifications/devices", params: { token: "fcm-1" }.to_json,
         headers: headers.merge("Authorization" => "Bearer #{other_token}")
    expect(DeviceToken.find_by(token: "fcm-1").user).to eq(other)
    expect(user.device_tokens.count).to eq(0)

    delete "/api/v1/notifications/devices", params: { token: "fcm-1" }.to_json, headers: headers
    expect(json["data"]).to eq("removed" => 0)
    expect(DeviceToken.exists?(token: "fcm-1")).to be(true)

    delete "/api/v1/notifications/devices", params: { token: "fcm-1" }.to_json,
           headers: headers.merge("Authorization" => "Bearer #{other_token}")
    expect(json["data"]).to eq("removed" => 1)
  end

  it "rejects invalid device platforms" do
    post "/api/v1/notifications/devices", params: { token: "fcm-2", platform: "tv" }.to_json, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "reads and updates preferences, ignoring unknown groups and channels" do
    get "/api/v1/notifications/preferences", headers: headers
    expect(json["data"]["groups"]["budgets"]).to eq("in_app" => true, "push" => true)

    put "/api/v1/notifications/preferences",
        params:  { groups: { budgets: { push: false }, bogus: { in_app: false }, insights: { sms: false } } }.to_json,
        headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"]["groups"]["budgets"]).to eq("in_app" => true, "push" => false)
    expect(json["data"]["groups"]["insights"]).to eq("in_app" => true, "push" => true)
    expect(json["data"]["groups"].keys).to match_array(Notification::GROUPS.values)
    expect(user.reload.settings.dig("notifications", "groups", "budgets", "push")).to be(false)
  end
end
