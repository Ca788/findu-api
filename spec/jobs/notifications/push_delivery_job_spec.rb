# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::PushDeliveryJob do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:notification) { create(:notification, user: user, channels: %w[in_app push]) }

  before do
    allow(Push::FcmClient).to receive(:configured?).and_return(true)
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
    it "enqueues one device job per user device" do
      first  = create(:device_token, user: user)
      second = create(:device_token, user: user)
      create(:device_token)

      expect { described_class.perform_now(notification.id) }
        .to have_enqueued_job(Notifications::PushDeviceDeliveryJob).with(notification.id, first.id)
        .and have_enqueued_job(Notifications::PushDeviceDeliveryJob).with(notification.id, second.id)
    end

    it "skips notifications without the push channel" do
      create(:device_token, user: user)
      in_app_only = create(:notification, user: user, channels: %w[in_app])

      expect { described_class.perform_now(in_app_only.id) }
        .not_to have_enqueued_job(Notifications::PushDeviceDeliveryJob)
    end

    it "skips notifications already read" do
      create(:device_token, user: user)
      read = create(:notification, :read, user: user, channels: %w[in_app push])

      expect { described_class.perform_now(read.id) }
        .not_to have_enqueued_job(Notifications::PushDeviceDeliveryJob)
    end

    it "skips when the user disabled push for the group" do
      create(:device_token, user: user)
      user.update!(settings: { "notifications" => { "groups" => { "entries_due" => { "push" => false } } } })

      expect { described_class.perform_now(notification.id) }
        .not_to have_enqueued_job(Notifications::PushDeviceDeliveryJob)
    end
  end
end
