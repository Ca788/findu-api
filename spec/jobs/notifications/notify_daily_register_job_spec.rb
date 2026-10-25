# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::NotifyDailyRegisterJob, type: :job do
  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  it "notifies each active user once per slot and day" do
    user    = create(:user)
    deleted = create(:user, deleted_at: Time.current)

    described_class.perform_now("morning")
    described_class.perform_now("morning")
    described_class.perform_now("noon")

    morning, noon = user.notifications.where(kind: "daily_register").order(:created_at)
    expect(user.notifications.where(kind: "daily_register").count).to eq(2)
    expect(morning).to have_attributes(title: "Hora de planejar o dia", dedupe_key: "daily_register:#{Date.current}:morning")
    expect(morning.data).to eq("route" => "/chat")
    expect(noon.dedupe_key).to eq("daily_register:#{Date.current}:noon")
    expect(deleted.notifications).to be_empty
  end

  it "ignores unknown slots" do
    user = create(:user)

    described_class.perform_now("evening")

    expect(user.notifications).to be_empty
  end
end
