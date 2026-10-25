# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::NotifyIdleUsersJob, type: :job do
  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  it "reminds only idle users older than a week, once per week" do
    idle   = create(:user, created_at: 30.days.ago)
    active = create(:user, created_at: 30.days.ago)
    fresh  = create(:user, created_at: 2.days.ago)
    create(:financial_transaction, user: active, created_at: 1.day.ago)
    create(:financial_transaction, user: idle, created_at: 20.days.ago)

    described_class.perform_now
    described_class.perform_now

    expect(idle.notifications.where(kind: "idle_reminder").count).to eq(1)
    expect(idle.notifications.first.data).to eq("route" => "/chat")
    expect(active.notifications).to be_empty
    expect(fresh.notifications).to be_empty
  end
end
