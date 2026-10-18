# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::Prompts::ChatAgentPromptBuilder do
  let(:today) { Date.new(2026, 10, 18) }
  let(:statement) do
    UseCase::Financial::Statements::ShowMonthlyStatementUseCase::Statement.new(
      month:               "2026-10",
      forecast:            { income: 0, expense: 0, balance: 0 },
      actual:              { income_paid: 0, expense_paid: 0, balance: 0 },
      counts:              { total: 0, pending: 0, paid: 0 },
      entries:             [],
      installments_active: [],
      recurrences_active:  [],
      by_category:         []
    )
  end
  let(:context) do
    UseCase::Chat::BuildUserContextUseCase::Context.new(
      statement: statement,
      budgets: [],
      recent_transactions: [],
      reference_date: today,
      goals: [],
      investments: []
    )
  end

  it "instructs the model to use light markdown and forbid em dashes" do
    prompt = described_class.new.call(context: context)

    expect(prompt).to include("Nunca use travessão")
    expect(prompt).to include("Markdown leve")
    expect(prompt).to include("R$ 1.234,56")
  end
end
