# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Notifications::NotifyDueEntriesUseCase do
  subject(:use_case) { described_class.new }

  let(:user)  { create(:user) }
  let(:today) { Date.new(2026, 10, 10) }

  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  it "notifies entries due today, due soon and overdue with stable dedupe keys" do
    today_entry = create(:financial_transaction, :expense, :pending, user: user, description: "Aluguel", amount: 1800, occurred_at: today.noon)
    soon_entry  = create(:financial_transaction, :expense, :pending, user: user, description: "Internet", amount: 120, occurred_at: (today + 2).noon)
    late_entry  = create(:financial_transaction, :expense, :pending, user: user, description: "Luz", amount: 90, occurred_at: (today - 5).noon)
    create(:financial_transaction, :expense, :pending, user: user, occurred_at: (today + 10).noon)
    create(:financial_transaction, :expense, :paid, user: user, occurred_at: today.noon)
    create(:financial_transaction, :income, :pending, user: user, occurred_at: today.noon)
    create(:financial_transaction, :expense, :pending, occurred_at: today.noon)

    notifications = use_case.call(user: user, today: today)

    expect(notifications.map { |n| [n.kind, n.dedupe_key] }).to match_array([
      ["entry_due_today", "entry_due_today:#{today_entry.id}"],
      ["entry_due_soon",  "entry_due_soon:#{soon_entry.id}"],
      ["entry_overdue",   "entry_overdue:#{late_entry.id}"]
    ])
    expect(notifications.find { |n| n.kind == "entry_due_today" }.title).to eq("Aluguel vence hoje: R$ 1.800,00")
    expect(notifications.find { |n| n.kind == "entry_due_soon" }.title).to eq("Internet vence em 2 dias: R$ 120,00")
    expect(notifications.find { |n| n.kind == "entry_overdue" }.data).to include("route" => "/statements/detail", "month" => "2026-10")

    expect(use_case.call(user: user, today: today)).to be_empty
  end

  it "moves an entry from due soon to due today without repeating the same stage" do
    entry = create(:financial_transaction, :expense, :pending, user: user, occurred_at: (today + 3).noon)

    expect(use_case.call(user: user, today: today).map(&:kind)).to eq(%w[entry_due_soon])
    expect(use_case.call(user: user, today: today + 3).map(&:kind)).to eq(%w[entry_due_today])
    expect(user.notifications.where("dedupe_key LIKE ?", "%#{entry.id}").count).to eq(2)
  end
end
