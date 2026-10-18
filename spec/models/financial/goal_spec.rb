# frozen_string_literal: true

require "rails_helper"

RSpec.describe Financial::Goal do
  let(:user) { create(:user) }

  describe "validations" do
    it "is invalid without a target amount" do
      goal = build(:financial_goal, user: user, target_amount: nil)

      expect(goal).not_to be_valid
    end

    it "is invalid with a negative current amount" do
      goal = build(:financial_goal, user: user, current_amount: -1)

      expect(goal).not_to be_valid
    end
  end

  describe "progress" do
    it "marks the goal as achieved when the target is reached" do
      goal = create(:financial_goal, user: user, target_amount: 1000, current_amount: 1000)

      expect(goal.status).to eq("achieved")
      expect(goal.achieved_at).to be_present
      expect(goal.progress_percent).to eq(100.0)
      expect(goal.remaining_amount).to eq(0)
    end

    it "reopens the goal when the saved amount drops below the target" do
      goal = create(:financial_goal, user: user, target_amount: 1000, current_amount: 1000)

      goal.update!(current_amount: 400)

      expect(goal.status).to eq("active")
      expect(goal.achieved_at).to be_nil
      expect(goal.remaining_amount).to eq(600)
    end

    it "keeps a canceled goal canceled" do
      goal = create(:financial_goal, user: user, target_amount: 1000, current_amount: 1000, status: "canceled")

      expect(goal.status).to eq("canceled")
    end
  end
end
