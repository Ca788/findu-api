# frozen_string_literal: true

class UseCase::Financial::Goal::CreateGoalUseCase
  # @param [User] user
  # @param [Hash] attributes
  # @return [Financial::Goal]
  def call(user:, attributes:)
    attrs = attributes.symbolize_keys.slice(*Financial::Goal::PERMITTED_ATTRIBUTES)
    attrs[:current_amount] = 0 if attrs[:current_amount].blank?
    ensure_status!(attrs[:status])
    ensure_category!(user, attrs)

    user.goals.create!(attrs)
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
