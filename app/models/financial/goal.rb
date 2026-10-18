# frozen_string_literal: true

# == Schema Information
#
# Table name: goals
#
#  id             :uuid             not null, primary key
#  achieved_at    :datetime
#  current_amount :decimal(10, 2)   default(0.0), not null
#  deadline       :date
#  name           :string           not null
#  notes          :text
#  status         :string           default("active"), not null
#  target_amount  :decimal(10, 2)   not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :uuid
#  user_id        :uuid             not null
#
# Indexes
#
#  index_goals_on_category_id         (category_id)
#  index_goals_on_user_id             (user_id)
#  index_goals_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Goal < ApplicationRecord
    STATUSES = {
      active:   "active",
      achieved: "achieved",
      canceled: "canceled"
    }.freeze

    PERMITTED_ATTRIBUTES = %i[
      name
      target_amount
      current_amount
      deadline
      category_id
      status
      notes
    ].freeze

    belongs_to :user
    belongs_to :category, class_name: "Financial::Category", optional: true

    enum status: STATUSES, _prefix: :status

    validates :name, presence: true
    validates :target_amount, presence: true, numericality: { greater_than: 0 }
    validates :current_amount, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true

    before_validation :sync_achievement

    scope :by_status,   ->(status)      { where(status: status) if status.present? && STATUSES.value?(status.to_s) }
    scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }

    # @return [BigDecimal]
    def remaining_amount
      [target_amount.to_d - current_amount.to_d, 0].max
    end

    # @return [Float]
    def progress_percent
      return 0.0 if target_amount.to_d.zero?

      ((current_amount.to_d / target_amount.to_d) * 100).round(2)
    end

    private

    def sync_achievement
      return if status_canceled?
      return if target_amount.blank?

      if current_amount.to_d >= target_amount.to_d
        self.status = "achieved"
        self.achieved_at ||= Time.current
      elsif status_achieved?
        self.status = "active"
        self.achieved_at = nil
      end
    end
  end
end
