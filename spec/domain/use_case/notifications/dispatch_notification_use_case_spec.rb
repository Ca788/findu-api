# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Notifications::DispatchNotificationUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  it "persists, broadcasts and dedupes by key" do
    expect(NotificationsChannel).to receive(:broadcast_to).once.with(
      user,
      hash_including(type: "notification.created", unread_count: 1)
    )

    first  = use_case.call(user: user, kind: :budget_warning, title: "Orçamento em 80%", dedupe_key: "budget_warning:1")
    second = use_case.call(user: user, kind: :budget_warning, title: "Orçamento em 80%", dedupe_key: "budget_warning:1")

    expect(first).to have_attributes(kind: "budget_warning", channels: %w[in_app push], read_at: nil)
    expect(second).to be_nil
    expect(user.notifications.count).to eq(1)
  end

  it "allows the same dedupe key for different users" do
    other = create(:user)

    use_case.call(user: user,  kind: :idle_reminder, title: "Oi", dedupe_key: "idle:2026-W43")
    use_case.call(user: other, kind: :idle_reminder, title: "Oi", dedupe_key: "idle:2026-W43")

    expect(Notification.count).to eq(2)
  end

  it "skips muted groups and records only enabled channels" do
    UseCase::Notifications::UpdateNotificationPreferencesUseCase.new.call(
      user:   user,
      groups: { budgets: { in_app: false, push: false }, insights: { push: false } }
    )

    expect(NotificationsChannel).to receive(:broadcast_to).once

    expect(use_case.call(user: user, kind: :budget_exceeded, title: "Estourou")).to be_nil
    expect(use_case.call(user: user, kind: :insights_ready, title: "Insights")).to have_attributes(channels: %w[in_app])
  end

  it "rejects unknown kinds" do
    expect { use_case.call(user: user, kind: :nope, title: "x") }.to raise_error(KeyError)
  end
end
