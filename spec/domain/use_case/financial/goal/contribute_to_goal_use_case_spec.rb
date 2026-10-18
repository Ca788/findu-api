# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Goal::ContributeToGoalUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }
  let!(:goal) { create(:financial_goal, user: user, target_amount: 1000, current_amount: 200) }

  describe "#call" do
    it "adds the contribution and achieves the goal when the target is reached" do
      result = use_case.call(user: user, id: goal.id, amount: 800)

      expect(result.current_amount).to eq(1000)
      expect(result.status).to eq("achieved")
      expect(result.progress_percent).to eq(100.0)
    end

    it "does not contribute to another user's goal" do
      expect {
        use_case.call(user: create(:user), id: goal.id, amount: 10)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "rejects a non-positive amount" do
      expect {
        use_case.call(user: user, id: goal.id, amount: 0)
      }.to raise_error(ArgumentError, /greater than 0/)
    end

    it "rejects a canceled goal" do
      goal.update!(status: "canceled", current_amount: 100)

      expect {
        use_case.call(user: user, id: goal.id, amount: 50)
      }.to raise_error(ArgumentError, /canceled/)
    end
  end
end
