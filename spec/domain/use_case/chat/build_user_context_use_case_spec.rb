# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::BuildUserContextUseCase do
  subject(:use_case) do
    described_class.new(statement_use_case: statement_use_case, budgets_use_case: budgets_use_case)
  end

  let(:user)             { create(:user) }
  let(:budgets_result)   { Struct.new(:budgets).new([]) }
  let(:statement_use_case) { instance_double(UseCase::Financial::Statements::ShowMonthlyStatementUseCase, call: :statement) }
  let(:budgets_use_case) do
    instance_double(UseCase::Financial::Budget::ListCurrentBudgetsUseCase, call: budgets_result)
  end

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  describe "#call" do
    it "builds the context for the user" do
      context = use_case.call(user: user)

      expect(context).to have_attributes(statement: :statement, budgets: [], reference_date: Date.current)
    end

    it "reuses the cached context while financial data is unchanged" do
      use_case.call(user: user)
      use_case.call(user: user)

      expect(statement_use_case).to have_received(:call).once
    end

    it "recomputes when the user's financial data changes" do
      use_case.call(user: user)
      create(:financial_transaction, user: user)
      use_case.call(user: user)

      expect(statement_use_case).to have_received(:call).twice
    end

    it "records cache hit information when timings are provided" do
      timings = {}
      use_case.call(user: user, timings: timings)
      expect(timings["context_cache_hit"]).to eq(false)

      use_case.call(user: user, timings: timings)
      expect(timings["context_cache_hit"]).to eq(true)
      expect(timings["context_fingerprint_ms"]).to be_a(Integer)
    end
  end
end
