# frozen_string_literal: true

class UseCase::Financial::Goal::UpdateGoalUseCase
  # @param [User] user
  # @param [String] id
  # @param [Hash] attributes
  # @return [Financial::Goal]
  def call(user:, id:, attributes:)
    goal  = user.goals.find(id)
    attrs = attributes.symbolize_keys.slice(*Financial::Goal::PERMITTED_ATTRIBUTES)
    ensure_status!(attrs[:status])
    ensure_category!(user, attrs)

    goal.update!(attrs)
    goal
  end

  private

  def ensure_status!(status)
    return if status.blank?
    return if Financial::Goal::STATUSES.value?(status.to_s)

    raise ArgumentError, "Invalid goal status"
  end

  def ensure_category!(user, attrs)
    return unless attrs.key?(:category_id)
    return if attrs[:category_id].blank?

    user.categories.find(attrs[:category_id])
  end
end
