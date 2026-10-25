# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::PushDeliveryJob do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:notification) { create(:notification, user: user, channels: %w[in_app push]) }
  let(:client)       { instance_double(Push::FcmClient) }

  before do
    allow(Push::FcmClient).to receive(:configured?).and_return(true)
    allow(Push::FcmClient).to receive(:new).and_return(client)
  end

  describe ".deliver_at" do
    it "delivers immediately inside the active window" do
      now = Time.zone.parse("2026-10-24 14:00")
      expect(described_class.deliver_at(now)).to eq(now)
    end

    it "postpones late-night notifications to 8h next day" do
      now = Time.zone.parse("2026-10-24 23:15")
      expect(described_class.deliver_at(now)).to eq(Time.zone.parse("2026-10-25 08:00"))
    end

    it "postpones early-morning notifications to 8h same day" do
      now = Time.zone.parse("2026-10-24 06:30")
      expect(described_class.deliver_at(now)).to eq(Time.zone.parse("2026-10-24 08:00"))
    end
  end

  describe ".schedule" do
    it "does nothing when the user has no devices" do
      expect { described_class.schedule(notification) }.not_to have_enqueued_job(described_class)
    end

    it "does nothing when FCM is not configured" do
      allow(Push::FcmClient).to receive(:configured?).and_return(false)
      create(:device_token, user: user)

      expect { described_class.schedule(notification) }.not_to have_enqueued_job(described_class)
    end

    it "enqueues when the user has a device" do
      create(:device_token, user: user)

      expect { described_class.schedule(notification) }.to have_enqueued_job(described_class).with(notification.id)
    end
  end

  describe "#perform" do
    it "sends to every device of the user with route data" do
      first  = create(:device_token, user: user)
      second = create(:device_token, user: user)
      create(:device_token)

      expect(client).to receive(:send_to_token).with(
        hash_including(token: first.token, title: notification.title, data: hash_including("route" => "/statements/detail", kind: "entry_due_today"))
      )
      expect(client).to receive(:send_to_token).with(hash_including(token: second.token))

      described_class.perform_now(notification.id)
    end

    it "removes tokens rejected as unregistered and keeps going" do
      dead  = create(:device_token, user: user)
      alive = create(:device_token, user: user)

      allow(client).to receive(:send_to_token).with(hash_including(token: dead.token)).and_raise(Push::FcmClient::Unregistered, "UNREGISTERED")
      allow(client).to receive(:send_to_token).with(hash_including(token: alive.token)).and_return({})

      described_class.perform_now(notification.id)

      expect(DeviceToken.exists?(dead.id)).to be(false)
      expect(DeviceToken.exists?(alive.id)).to be(true)
    end

    it "skips notifications without the push channel" do
      create(:device_token, user: user)
      in_app_only = create(:notification, user: user, channels: %w[in_app])

      expect(client).not_to receive(:send_to_token)

      described_class.perform_now(in_app_only.id)
    end
  end
end
