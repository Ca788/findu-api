# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviceToken do
  describe ".register" do
    let(:user) { create(:user) }

    it "creates a token and refreshes last_seen_at on the same row" do
      first = described_class.register(user: user, token: "fcm-1", platform: "android")

      travel 1.minute do
        second = described_class.register(user: user, token: "fcm-1", platform: "android")
        expect(second.id).to eq(first.id)
        expect(second.last_seen_at).to be > first.last_seen_at
      end

      expect(described_class.where(token: "fcm-1").count).to eq(1)
    end

    it "reassigns the token when another user registers it" do
      described_class.register(user: user, token: "fcm-1", platform: "android")
      other = create(:user)

      record = described_class.register(user: other, token: "fcm-1", platform: "ios")

      expect(record.user).to eq(other)
      expect(record.platform).to eq("ios")
      expect(described_class.where(token: "fcm-1").count).to eq(1)
    end

    it "rejects unknown platforms" do
      expect {
        described_class.register(user: user, token: "fcm-1", platform: "tv")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
