# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id              :uuid             not null, primary key
#  asset_type      :string           default("other"), not null
#  current_amount  :decimal(10, 2)   default(0.0), not null
#  institution     :string
#  invested_amount :decimal(10, 2)   not null
#  invested_on     :date             not null
#  name            :string           not null
#  notes           :text
#  status          :string           default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_investments_on_user_id                 (user_id)
#  index_investments_on_user_id_and_asset_type  (user_id,asset_type)
#  index_investments_on_user_id_and_status      (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Investment < ApplicationRecord
    ASSET_TYPES = {
      fixed_income: "fixed_income",
      stocks:       "stocks",
      funds:        "funds",
      treasury:     "treasury",
      crypto:       "crypto",
      other:        "other"
    }.freeze

    STATUSES = {
      active:   "active",
      redeemed: "redeemed"
    }.freeze

    PERMITTED_ATTRIBUTES = %i[
      name
      asset_type
      institution
      invested_amount
      current_amount
      invested_on
      status
      notes
    ].freeze

    belongs_to :user

    enum asset_type: ASSET_TYPES, _prefix: :asset
    enum status:     STATUSES, _prefix: :status

    validates :name, presence: true
    validates :asset_type, presence: true
    validates :invested_amount, presence: true, numericality: { greater_than: 0 }
    validates :current_amount, numericality: { greater_than_or_equal_to: 0 }
    validates :invested_on, presence: true
    validates :status, presence: true

    scope :by_status,     ->(status)     { where(status: status) if status.present? && STATUSES.value?(status.to_s) }
    scope :by_asset_type, ->(asset_type) { where(asset_type: asset_type) if asset_type.present? && ASSET_TYPES.value?(asset_type.to_s) }

    # @return [BigDecimal]
    def return_amount
      current_amount.to_d - invested_amount.to_d
    end

    # @return [Float]
    def return_percent
      return 0.0 if invested_amount.to_d.zero?

      ((return_amount / invested_amount.to_d) * 100).round(2)
    end
  end
end
