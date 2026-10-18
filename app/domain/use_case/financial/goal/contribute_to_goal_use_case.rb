# frozen_string_literal: true

class UseCase::Financial::Goal::ContributeToGoalUseCase
  # @param [User] user
  # @param [String] id
  # @param [Numeric, String] amount
  # @return [Financial::Goal]
  def call(user:, id:, amount:)
    value = amount.to_d
    raise ArgumentError, "amount must be greater than 0" unless value.positive?

    goal = user.goals.find(id)
    raise ArgumentError, "Cannot contribute to a canceled goal" if goal.status_canceled?

    goal.with_lock do
      goal.current_amount = goal.current_amount.to_d + value
      goal.save!
    end

    goal
  end
end
