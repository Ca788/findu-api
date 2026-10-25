# frozen_string_literal: true

class Notification < ApplicationRecord
  GROUPS = {
    entries_due:  "entries_due",
    budgets:      "budgets",
    insights:     "insights",
    installments: "installments",
    reminders:    "reminders"
  }.freeze

  KINDS = {
    entry_due_soon:        GROUPS[:entries_due],
    entry_due_today:       GROUPS[:entries_due],
    entry_overdue:         GROUPS[:entries_due],
    budget_warning:        GROUPS[:budgets],
    budget_exceeded:       GROUPS[:budgets],
    insights_ready:        GROUPS[:insights],
    installment_completed: GROUPS[:installments],
    idle_reminder:         GROUPS[:reminders]
  }.freeze

  CHANNELS = %w[in_app push].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }
  validates :title, presence: true, length: { maximum: 120 }
  validates :body, length: { maximum: 500 }, allow_nil: true

  scope :unread,  -> { where(read_at: nil) }
  scope :recent,  -> { order(created_at: :desc) }
  scope :by_kind, ->(kind) { where(kind: kind) if kind.present? && KINDS.key?(kind.to_s.to_sym) }

  def self.group_for(kind)
    KINDS.fetch(kind.to_s.to_sym)
  end

  def group
    self.class.group_for(kind)
  end

  def read?
    read_at.present?
  end
end
