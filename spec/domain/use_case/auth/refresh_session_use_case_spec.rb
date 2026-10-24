# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Auth::RefreshSessionUseCase do
  subject(:use_case) { described_class.new }

  let(:user)   { create(:user) }
  let(:issued) { RefreshToken.issue!(user: user, client: "web") }

  it "rotates the refresh token and returns a new access token" do
    result = use_case.call(refresh_token: issued.token)

    expect(result.user).to eq(user)
    expect(result.access_token).to be_present
    expect(result.refresh_token).to be_present
    expect(result.refresh_token).not_to eq(issued.token)
    expect(issued.record.reload).not_to be_active
    expect(RefreshToken.find_by_token(result.refresh_token)).to be_active
  end

  it "keeps the new token in the same family and inherits the client" do
    result = use_case.call(refresh_token: issued.token)
    rotated = RefreshToken.find_by_token(result.refresh_token)

    expect(rotated.family_id).to eq(issued.record.family_id)
    expect(rotated.client).to eq("web")
  end

  it "issues an access token that decodes to the user" do
    result  = use_case.call(refresh_token: issued.token)
    payload = Warden::JWTAuth::TokenDecoder.new.call(result.access_token)

    expect(payload["sub"]).to eq(user.id)
    expect(payload["jti"]).to eq(user.jti)
  end

  it "rejects an unknown token" do
    expect { use_case.call(refresh_token: "nope") }
      .to raise_error(described_class::InvalidRefreshToken)
  end

  it "rejects a blank token" do
    expect { use_case.call(refresh_token: nil) }
      .to raise_error(described_class::InvalidRefreshToken)
  end

  it "rejects an expired token" do
    issued.record.update!(expires_at: 1.minute.ago)

    expect { use_case.call(refresh_token: issued.token) }
      .to raise_error(described_class::InvalidRefreshToken)
  end

  it "revokes the whole family when a rotated token is reused" do
    first  = use_case.call(refresh_token: issued.token)
    second = use_case.call(refresh_token: first.refresh_token)

    expect { use_case.call(refresh_token: issued.token) }
      .to raise_error(described_class::InvalidRefreshToken)

    expect(RefreshToken.find_by_token(second.refresh_token)).not_to be_active
    expect(user.refresh_tokens.active).to be_empty
  end

  it "rejects tokens of soft-deleted users" do
    user.update!(deleted_at: Time.current)

    expect { use_case.call(refresh_token: issued.token) }
      .to raise_error(described_class::InvalidRefreshToken)
  end
end
