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

  def stub_http(fcm:, oauth: { access_token: "ya29.test" })
    allow(Net::HTTP).to receive(:start) do |host, _port, **_opts, &block|
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request) do |req|
        if host == described_class::TOKEN_URI.host
          oauth.respond_to?(:call) ? oauth.call(req) : http_response(Net::HTTPOK, 200, oauth)
        else
          fcm.respond_to?(:call) ? fcm.call(req) : fcm
        end
      end
      block.call(http)
    end
  end

  it "exchanges a signed JWT for an access token and posts to the project endpoint" do
    captured = nil
    stub_http(fcm: lambda { |req|
      captured = req
      http_response(Net::HTTPOK, 200, name: "projects/findu-test/messages/1")
    })

    result = client.send_to_token(
      token:        "abc",
      title:        "Oi",
      body:         "Corpo",
      data:         { route: "/budgets", budget_id: 7 },
      collapse_key: "budget_warning"
    )

    expect(result).to eq("name" => "projects/findu-test/messages/1")
    expect(captured.path).to eq("/v1/projects/findu-test/messages:send")
    expect(captured["Authorization"]).to eq("Bearer ya29.test")

    message = JSON.parse(captured.body)["message"]
    expect(message["token"]).to eq("abc")
    expect(message["data"]).to eq("route" => "/budgets", "budget_id" => "7")
    expect(message.dig("android", "notification", "channel_id")).to eq("findu_default")
    expect(message.dig("android", "collapse_key")).to eq("budget_warning")
  end

  it "raises Unregistered when FCM reports a dead token" do
    stub_http(fcm: http_response(Net::HTTPNotFound, 404, error: {
      status:  "NOT_FOUND",
      details: [{ errorCode: "UNREGISTERED" }]
    }))

    expect { client.send_to_token(token: "dead", title: "Oi", body: nil) }
      .to raise_error(described_class::Unregistered, "UNREGISTERED")
  end

  it "raises Unregistered when INVALID_ARGUMENT refers to the registration token" do
    stub_http(fcm: http_response(Net::HTTPBadRequest, 400, error: {
      status:  "INVALID_ARGUMENT",
      message: "The registration token is not a valid FCM registration token",
      details: [{ errorCode: "INVALID_ARGUMENT" }]
    }))

    expect { client.send_to_token(token: "bad", title: "Oi", body: nil) }
      .to raise_error(described_class::Unregistered, "INVALID_ARGUMENT")
  end

  it "raises Error when INVALID_ARGUMENT is a payload bug" do
    stub_http(fcm: http_response(Net::HTTPBadRequest, 400, error: {
      status:  "INVALID_ARGUMENT",
      message: "Invalid data payload. Keys must be strings",
      details: [{ errorCode: "INVALID_ARGUMENT" }]
    }))

    expect { client.send_to_token(token: "x", title: "Oi", body: nil) }
      .to raise_error(described_class::Error, /INVALID_ARGUMENT/)
  end

  it "raises Transient for FCM 5xx" do
    stub_http(fcm: http_response(Net::HTTPInternalServerError, 500, error: { status: "INTERNAL" }))

    expect { client.send_to_token(token: "x", title: "Oi", body: nil) }
      .to raise_error(described_class::Transient, /INTERNAL/)
  end

  it "invalidates the cached access token and retries once on 401" do
    calls = 0
    stub_http(fcm: lambda { |_req|
      calls += 1
      if calls == 1
        http_response(Net::HTTPUnauthorized, 401, error: { status: "UNAUTHENTICATED" })
      else
        http_response(Net::HTTPOK, 200, name: "projects/findu-test/messages/1")
      end
    })
    allow(Rails.cache).to receive(:delete).and_call_original

    result = client.send_to_token(token: "abc", title: "Oi", body: nil)

    expect(result).to eq("name" => "projects/findu-test/messages/1")
    expect(Rails.cache).to have_received(:delete).with(described_class::CACHE_KEY)
    expect(calls).to eq(2)
  end

  it "raises Transient on network timeouts" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

    expect { client.send_to_token(token: "x", title: "Oi", body: nil) }
      .to raise_error(described_class::Transient, /ReadTimeout/)
  end

  it "reports configured? from the environment" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("FCM_SERVICE_ACCOUNT_JSON").and_return(nil)
    expect(described_class.configured?).to be(false)

    allow(ENV).to receive(:[]).with("FCM_SERVICE_ACCOUNT_JSON").and_return(service_account)
    expect(described_class.configured?).to be(true)
  end
end
