# frozen_string_literal: true

# == Schema Information
#
# Table name: boxes
#
#  id               :uuid             not null, primary key
#  archived_at      :datetime
#  balance          :decimal(12, 2)   default(0.0), not null
#  color            :string
#  illustration_key :string           default("piggy"), not null
#  kind             :string           default("custom"), not null
#  name             :string           not null
#  notes            :text
#  position         :integer          default(0), not null
#  target_amount    :decimal(10, 2)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :uuid             not null
#
# Indexes
#
#  index_boxes_on_user_id                               (user_id)
#  index_boxes_on_user_id_and_archived_at_and_position  (user_id,archived_at,position)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Box < ApplicationRecord
    KINDS = {
      emergency:          "emergency",
      goal:               "goal",
      spending:           "spending",
      recurring_expenses: "recurring_expenses",
      custom:             "custom"
    }.freeze

    ILLUSTRATION_KEYS = %w[
      piggy shield house plane car gift heart coins rocket umbrella briefcase graduation
    ].freeze

    PERMITTED_ATTRIBUTES = %i[
      name
      kind
      illustration_key
      color
      target_amount
      position
      notes
    ].freeze

    belongs_to :user
    has_many :movements, class_name: "Financial::BoxMovement", dependent: :destroy

    enum kind: KINDS, _prefix: :kind

    validates :name, presence: true, length: { maximum: 60 }
    validates :illustration_key, inclusion: { in: ILLUSTRATION_KEYS }
    validates :target_amount, numericality: { greater_than: 0 }, allow_nil: true
    validates :balance, numericality: { greater_than_or_equal_to: 0 }
    validates :color, format: { with: /\A#\h{6}\z/ }, allow_blank: true

    scope :active,   -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :by_kind,  ->(kind) { where(kind: kind) if kind.present? && KINDS.value?(kind.to_s) }
    scope :ordered,  -> { order(:position, :created_at) }

    # @return [Boolean]
    def archived?
      archived_at.present?
    end

    # @return [BigDecimal, nil]
    def remaining_amount
      return nil if target_amount.blank?

      [target_amount.to_d - balance.to_d, 0].max
    end

    # @return [Float, nil]
    def progress_percent
      return nil if target_amount.blank? || target_amount.to_d.zero?

      [((balance.to_d / target_amount.to_d) * 100).round(2).to_f, 100.0].min
    end
  end
end
