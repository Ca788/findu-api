# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::PurgeStaleDeviceTokensJob do
  it "deletes tokens not seen in 60 days and keeps the rest" do
    stale  = create(:device_token, last_seen_at: 61.days.ago)
    recent = create(:device_token, last_seen_at: 2.days.ago)

    described_class.perform_now

    expect(DeviceToken.exists?(stale.id)).to be(false)
    expect(DeviceToken.exists?(recent.id)).to be(true)
  end
end
