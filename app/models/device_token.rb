# frozen_string_literal: true

class DeviceToken < ApplicationRecord
  PLATFORMS = %w[android ios web].freeze

  belongs_to :user

  validates :token, presence: true, uniqueness: true, length: { maximum: 4096 }
  validates :platform, inclusion: { in: PLATFORMS }

  def self.register(user:, token:, platform:)
    record = find_or_initialize_by(token: token)
    record.assign_attributes(user: user, platform: platform, last_seen_at: Time.current)
    record.save!
    record
  end
end
