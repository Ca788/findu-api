# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Notifications::NotifyBudgetWarningsUseCase do
  let(:user)   { create(:user) }
  let(:budget) { create(:financial_budget, user: user, limit_amount: 1000) }

  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  def warnings_for
    UseCase::Financial::Budget::CheckBudgetConsumptionUseCase.new.call(user: user)
  end

  it "notifies once when crossing 80% and again when exceeding 100%" do
    create(:financial_transaction, :expense, :paid, user: user, amount: 850, occurred_at: budget.period_start.noon)

    first = described_class.new.call(user: user, warnings: warnings_for)
    expect(first.map(&:kind)).to eq(%w[budget_warning])
    expect(first.first.title).to eq("Orçamento em 85% do limite")
    expect(first.first.body).to start_with("R$ 850,00 de R$ 1.000,00")

    expect(described_class.new.call(user: user, warnings: warnings_for)).to be_empty

    create(:financial_transaction, :expense, :paid, user: user, amount: 300, occurred_at: budget.period_start.noon)
    budget.reload

    second = described_class.new.call(user: user, warnings: warnings_for)
    expect(second.map(&:kind)).to eq(%w[budget_exceeded])
    expect(second.first.data).to include("route" => "/budgets", "budget_id" => budget.id)
  end

  it "is triggered by creating an expense through the transaction use case" do
    budget

    expect {
      UseCase::Financial::Transaction::CreateTransactionUseCase.new.call(
        user:             user,
        amount:           900,
        transaction_type: "expense",
        description:      "Mercado",
        status:           "paid",
        occurred_at:      budget.period_start.noon
      )
    }.to change { user.notifications.where(kind: "budget_warning").count }.by(1)
  end
end
