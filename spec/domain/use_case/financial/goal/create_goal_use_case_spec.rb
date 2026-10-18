# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Financial::Goal::CreateGoalUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  describe "#call" do
    it "creates a goal scoped to the user" do
      expect {
        use_case.call(user: user, attributes: { name: "Reserva", target_amount: 8000 })
      }.to change(user.goals, :count).by(1)
    end

    it "rejects a category that belongs to another user" do
      category = create(:financial_category)

      expect {
        use_case.call(
          user: user,
          attributes: { name: "Reserva", target_amount: 8000, category_id: category.id }
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "links a category that belongs to the user" do
      category = create(:financial_category, user: user)

      goal = use_case.call(
        user: user,
        attributes: { name: "Reserva", target_amount: 8000, category_id: category.id, deadline: Date.new(2026, 12, 31) }
      )

      expect(goal.category_id).to eq(category.id)
      expect(goal.deadline).to eq(Date.new(2026, 12, 31))
      expect(goal.current_amount).to eq(0)
    end
  end
end
