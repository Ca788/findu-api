# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Investment::CreateInvestmentUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  describe "#call" do
    it "creates an investment scoped to the user and defaults the current amount" do
      investment = use_case.call(
        user: user,
        attributes: {
          name: "IVVB11",
          asset_type: "funds",
          invested_amount: 500,
          invested_on: Date.new(2026, 9, 1)
        }
      )

      expect(investment.user_id).to eq(user.id)
      expect(investment.current_amount).to eq(500)
      expect(investment.asset_type).to eq("funds")
      expect(user.investments).to include(investment)
    end

    it "rejects an unknown asset type" do
      expect {
        use_case.call(
          user: user,
          attributes: {
            name: "IVVB11",
            asset_type: "pokemon",
            invested_amount: 500,
            invested_on: Date.current
          }
        )
      }.to raise_error(ArgumentError, /asset type/)
    end
  end
end
