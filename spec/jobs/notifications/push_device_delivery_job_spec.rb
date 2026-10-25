# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::PushDeviceDeliveryJob do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:notification) { create(:notification, user: user, channels: %w[in_app push]) }
  let(:device)       { create(:device_token, user: user) }
  let(:client)       { instance_double(Push::FcmClient) }

  before do
    allow(Push::FcmClient).to receive(:configured?).and_return(true)
    allow(Push::FcmClient).to receive(:new).and_return(client)
  end

  it "sends to the device with route data, platform and collapse key" do
    expect(client).to receive(:send_to_token).with(
      hash_including(
        token:        device.token,
        title:        notification.title,
        body:         notification.body,
        platform:     device.platform,
        collapse_key: notification.kind,
        data:         hash_including("route" => "/statements/detail", kind: "entry_due_today")
      )
    )

    described_class.perform_now(notification.id, device.id)
  end

  it "removes tokens rejected as unregistered" do
    allow(client).to receive(:send_to_token).and_raise(Push::FcmClient::Unregistered, "UNREGISTERED")

    described_class.perform_now(notification.id, device.id)

    expect(DeviceToken.exists?(device.id)).to be(false)
  end

  it "alerts on permanent FCM errors without raising" do
    allow(client).to receive(:send_to_token).and_raise(Push::FcmClient::Error, "INVALID_ARGUMENT")
    allow(Alert).to receive(:notify)

    expect { described_class.perform_now(notification.id, device.id) }.not_to raise_error
    expect(Alert).to have_received(:notify).with(
      "[push] delivery failed",
      hash_including(context: hash_including(notification_id: notification.id, device_id: device.id))
    )
  end

  it "skips when the notification was already read" do
    notification.update!(read_at: Time.current)
    expect(client).not_to receive(:send_to_token)

    described_class.perform_now(notification.id, device.id)
  end
end
