# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  deleted_at             :datetime
#  email                  :string           not null
#  encrypted_password     :string           default(""), not null
#  jti                    :string           not null
#  name                   :string           not null
#  phone                  :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  settings               :jsonb
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_jti                   (jti) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  AVATAR_ALLOWED_TYPES = %w[image/png image/jpeg image/webp].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  devise :database_authenticatable,
         :recoverable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: self

  has_many :artifacts, dependent: :destroy
  has_many :categories, class_name: "Financial::Category", dependent: :destroy
  has_many :transactions, class_name: "Financial::Transaction", dependent: :destroy
  has_many :budgets, class_name: "Financial::Budget", dependent: :destroy
  has_many :goals, class_name: "Financial::Goal", dependent: :destroy
  has_many :investments, class_name: "Financial::Investment", dependent: :destroy
  has_many :receipts, class_name: "Financial::Receipt", dependent: :destroy
  has_many :recurrence_rules, class_name: "Financial::RecurrenceRule", dependent: :destroy
  has_many :installment_plans, class_name: "Financial::InstallmentPlan", dependent: :destroy
  has_many :insights, class_name: "Intelligence::Insight", dependent: :destroy
  has_many :chat_conversations, class_name: "Chat::Conversation", dependent: :destroy
  has_many :chat_messages, class_name: "Chat::Message", dependent: :destroy

  has_one_attached :avatar, dependent: :purge_later

  validates :name, presence: true
  validate :avatar_format_and_size

  private

  def avatar_format_and_size
    return unless avatar.attached?

    unless AVATAR_ALLOWED_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be PNG, JPEG or WEBP")
    end

    if avatar.blob.byte_size > AVATAR_MAX_SIZE
      errors.add(:avatar, "must be smaller than 5MB")
    end
  end
end
