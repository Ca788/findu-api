# frozen_string_literal: true

class UseCase::Financial::Investment::ListInvestmentsUseCase
  # @param [User] user
  # @param [String, nil] status
  # @param [String, nil] asset_type
  # @return [ActiveRecord::Relation<Financial::Investment>]
  def call(user:, status: nil, asset_type: nil)
    user.investments
        .by_status(status)
        .by_asset_type(asset_type)
        .order(invested_on: :desc, created_at: :desc)
  end
end
