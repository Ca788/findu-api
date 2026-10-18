# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Goal::ListGoalsUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  describe "#call" do
    it "returns only the user's goals and filters by status" do
      active = create(:financial_goal, user: user, name: "Viagem", current_amount: 10, target_amount: 100)
      create(:financial_goal, user: user, name: "Casa", target_amount: 100, current_amount: 100)
      create(:financial_goal, name: "De outro")

      result = use_case.call(user: user, status: "active")

      expect(result).to contain_exactly(active)
    end
  end
end
