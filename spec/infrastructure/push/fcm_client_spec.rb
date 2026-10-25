# frozen_string_literal: true

require "rails_helper"

RSpec.describe Push::FcmClient do
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:service_account) do
    {
      type:         "service_account",
      project_id:   "findu-test",
      client_email: "fcm@findu-test.iam.gserviceaccount.com",
      private_key:  private_key.to_pem
    }.to_json
  end

  subject(:client) { described_class.new(service_account: service_account) }

  def http_response(klass, code, body)
    klass.new("1.1", code.to_s, "").tap do |response|
      allow(response).to receive(:body).and_return(body.to_json)
    end
  end

  before do
    allow(Net::HTTP).to receive(:post_form).and_return(http_response(Net::HTTPOK, 200, access_token: "ya29.test"))
  end

  it "exchanges a signed JWT for an access token and posts to the project endpoint" do
    captured = nil
    allow(Net::HTTP).to receive(:start) do |host, _port, **_opts, &block|
      expect(host).to eq("fcm.googleapis.com")
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request) { |req| captured = req; http_response(Net::HTTPOK, 200, name: "projects/findu-test/messages/1") }
      block.call(http)
    end

    result = client.send_to_token(token: "abc", title: "Oi", body: "Corpo", data: { route: "/budgets", budget_id: 7 })

    expect(result).to eq("name" => "projects/findu-test/messages/1")
    expect(captured.path).to eq("/v1/projects/findu-test/messages:send")
    expect(captured["Authorization"]).to eq("Bearer ya29.test")

    message = JSON.parse(captured.body)["message"]
    expect(message["token"]).to eq("abc")
    expect(message["data"]).to eq("route" => "/budgets", "budget_id" => "7")
    expect(message.dig("android", "notification", "channel_id")).to eq("findu_default")

    expect(Net::HTTP).to have_received(:post_form) do |uri, form|
      expect(uri).to eq(described_class::TOKEN_URI)
      expect(form[:grant_type]).to eq("urn:ietf:params:oauth:grant-type:jwt-bearer")
      claims, = JWT.decode(form[:assertion], private_key.public_key, true, algorithm: "RS256")
      expect(claims).to include("iss" => "fcm@findu-test.iam.gserviceaccount.com", "scope" => described_class::SCOPE)
    end
  end

  it "raises Unregistered when FCM reports a dead token" do
    allow(Net::HTTP).to receive(:start) do |*_args, **_opts, &block|
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(
        http_response(Net::HTTPNotFound, 404, error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] })
      )
      block.call(http)
    end

    expect { client.send_to_token(token: "dead", title: "Oi", body: nil) }.to raise_error(described_class::Unregistered, "UNREGISTERED")
  end

  it "raises Error for other failures" do
    allow(Net::HTTP).to receive(:start) do |*_args, **_opts, &block|
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(http_response(Net::HTTPInternalServerError, 500, error: { status: "INTERNAL" }))
      block.call(http)
    end

    expect { client.send_to_token(token: "x", title: "Oi", body: nil) }.to raise_error(described_class::Error, /INTERNAL/)
  end

  it "reports configured? from the environment" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("FCM_SERVICE_ACCOUNT_JSON").and_return(nil)
    expect(described_class.configured?).to be(false)

    allow(ENV).to receive(:[]).with("FCM_SERVICE_ACCOUNT_JSON").and_return(service_account)
    expect(described_class.configured?).to be(true)
  end
end
