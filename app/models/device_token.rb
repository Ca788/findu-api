# frozen_string_literal: true

class DeviceToken < ApplicationRecord
  PLATFORMS = %w[android ios web].freeze

  belongs_to :user

  validates :token, presence: true, length: { maximum: 4096 }
  validates :platform, inclusion: { in: PLATFORMS }

  def self.register(user:, token:, platform:)
    candidate = new(user: user, token: token, platform: platform, last_seen_at: Time.current)
    candidate.validate!

    upsert(
      {
        user_id:      candidate.user_id,
        token:        candidate.token,
        platform:     candidate.platform,
        last_seen_at: candidate.last_seen_at
      },
      unique_by: :token
    )
    find_by!(token: candidate.token)
  end
end
