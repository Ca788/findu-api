# frozen_string_literal: true

# == Schema Information
#
# Table name: box_movements
#
#  id             :uuid             not null, primary key
#  amount         :decimal(12, 2)   not null
#  balance_after  :decimal(12, 2)   not null
#  description    :string
#  kind           :string           not null
#  occurred_at    :datetime         not null
#  source         :string           default("manual"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  box_id         :uuid             not null
#  transaction_id :uuid
#  user_id        :uuid             not null
#
# Indexes
#
#  index_box_movements_on_box_id                     (box_id)
#  index_box_movements_on_box_id_and_occurred_at     (box_id,occurred_at)
#  index_box_movements_on_transaction_id             (transaction_id)
#  index_box_movements_on_transaction_id_and_box_id  (transaction_id,box_id) UNIQUE WHERE (transaction_id IS NOT NULL)
#  index_box_movements_on_user_id                    (user_id)
#  index_box_movements_on_user_id_and_occurred_at    (user_id,occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (box_id => boxes.id)
#  fk_rails_...  (transaction_id => transactions.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class BoxMovement < ApplicationRecord
    KINDS = {
      deposit:    "deposit",
      withdraw:   "withdraw",
      adjustment: "adjustment"
    }.freeze

    SOURCES = {
      manual:     "manual",
      allocation: "allocation",
      chat:       "chat"
    }.freeze

    belongs_to :box, class_name: "Financial::Box"
    belongs_to :user
    belongs_to :transaction_record,
               class_name:  "Financial::Transaction",
               foreign_key: :transaction_id,
               optional:    true,
               inverse_of:  false

    enum kind:   KINDS,   _prefix: :kind
    enum source: SOURCES, _prefix: :source

    validates :amount, presence: true, numericality: { other_than: 0 }
    validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :occurred_at, presence: true
    validates :description, length: { maximum: 140 }, allow_blank: true

    scope :recent, -> { order(occurred_at: :desc, created_at: :desc) }
  end
end
