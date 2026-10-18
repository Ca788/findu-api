# frozen_string_literal: true

require "rails_helper"

RSpec.describe Financial::Investment do
  let(:user) { create(:user) }

  describe "returns" do
    it "calculates profit and percent against the invested amount" do
      investment = build(
        :financial_investment,
        user: user,
        invested_amount: 1_000,
        current_amount: 1_250
      )

      expect(investment.return_amount).to eq(250)
      expect(investment.return_percent).to eq(25.0)
    end

    it "is invalid without an invested amount" do
      investment = build(:financial_investment, user: user, invested_amount: nil)

      expect(investment).not_to be_valid
    end
  end
end
