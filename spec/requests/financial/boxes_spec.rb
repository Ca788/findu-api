# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Financial boxes", type: :request do
  let(:user)  { create(:user) }
  let(:token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }
  let(:headers) do
    { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  def json
    JSON.parse(response.body)
  end

  it "creates a box with initial balance, lists it with pagination and metadata" do
    post "/api/v1/financial/boxes",
         params:  { box: { name: "Apartamento", kind: "goal", illustration_key: "house", target_amount: 50_000, initial_balance: 1_200 } }.to_json,
         headers: headers

    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("name" => "Apartamento", "balance" => "1200.0", "progress_percent" => 2.4)

    get "/api/v1/financial/boxes", params: { per_page: 5 }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"].size).to eq(1)
    expect(json["pagination"]).to include("totalCount" => 1)
    expect(json["metadata"]["illustration_keys"]).to include("house")
  end

  it "moves funds and exposes the ledger" do
    box = create(:financial_box, user: user)

    post "/api/v1/financial/boxes/#{box.id}/move",
         params: { movement: { kind: "deposit", amount: 300, description: "Salário" } }.to_json, headers: headers
    expect(response).to have_http_status(:created)
    expect(json["data"]["box"]["balance"]).to eq("300.0")

    post "/api/v1/financial/boxes/#{box.id}/move",
         params: { movement: { kind: "withdraw", amount: 500 } }.to_json, headers: headers
    expect(response).to have_http_status(:bad_request).or have_http_status(:unprocessable_entity)

    get "/api/v1/financial/boxes/#{box.id}/movements", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"].map { |m| m["kind"] }).to eq(["deposit"])
  end

  it "never leaks another user's box" do
    foreign = create(:financial_box)

    get "/api/v1/financial/boxes/#{foreign.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    post "/api/v1/financial/boxes/#{foreign.id}/move",
         params: { movement: { kind: "deposit", amount: 1 } }.to_json, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "refuses to archive a box with balance and archives once empty" do
    box = create(:financial_box, user: user)
    UseCase::Financial::Box::MoveBoxFundsUseCase.new.call(user: user, id: box.id, kind: "deposit", amount: 10)

    post "/api/v1/financial/boxes/#{box.id}/archive", headers: headers
    expect(response).not_to have_http_status(:ok)

    UseCase::Financial::Box::MoveBoxFundsUseCase.new.call(user: user, id: box.id, kind: "withdraw", amount: 10)
    post "/api/v1/financial/boxes/#{box.id}/archive", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]["archived"]).to be(true)

    get "/api/v1/financial/boxes", headers: headers
    expect(json["data"]).to be_empty
    get "/api/v1/financial/boxes", params: { archived: true }, headers: headers
    expect(json["data"].size).to eq(1)
  end
end
