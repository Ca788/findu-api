# frozen_string_literal: true

class UseCase::Financial::Goal::ListGoalsUseCase
  # @param [User] user
  # @param [String, nil] status
  # @param [String, nil] category_id
  # @return [ActiveRecord::Relation<Financial::Goal>]
  def call(user:, status: nil, category_id: nil)
    user.goals
        .includes(:category)
        .by_status(status)
        .by_category(category_id)
        .order(deadline: :asc, created_at: :desc)
  end
end
