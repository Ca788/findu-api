# frozen_string_literal: true

class UseCase::Financial::Investment::UpdateInvestmentUseCase
  # @param [User] user
  # @param [String] id
  # @param [Hash] attributes
  # @return [Financial::Investment]
  def call(user:, id:, attributes:)
    investment = user.investments.find(id)
    attrs      = attributes.symbolize_keys.slice(*Financial::Investment::PERMITTED_ATTRIBUTES)
    ensure_asset_type!(attrs[:asset_type])
    ensure_status!(attrs[:status])

    investment.update!(attrs)
    investment
  end

  private

  def ensure_asset_type!(asset_type)
    return if asset_type.blank?
    return if Financial::Investment::ASSET_TYPES.value?(asset_type.to_s)

    raise ArgumentError, "Invalid investment asset type"
  end

  def ensure_status!(status)
    return if status.blank?
    return if Financial::Investment::STATUSES.value?(status.to_s)

    raise ArgumentError, "Invalid investment status"
  end
end
