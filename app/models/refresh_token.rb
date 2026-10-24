# frozen_string_literal: true

# == Schema Information
#
# Table name: refresh_tokens
#
#  id           :uuid             not null, primary key
#  client       :string
#  expires_at   :datetime         not null
#  last_used_at :datetime
#  revoked_at   :datetime
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  family_id    :uuid             not null
#  user_id      :uuid             not null
#
# Indexes
#
#  index_refresh_tokens_on_token_digest           (token_digest) UNIQUE
#  index_refresh_tokens_on_user_id                (user_id)
#  index_refresh_tokens_on_user_id_and_family_id  (user_id,family_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class RefreshToken < ApplicationRecord
  TTL = ENV.fetch("REFRESH_TOKEN_TTL_DAYS", "30").to_i.days

  Issued = Struct.new(:record, :token, keyword_init: true)

  belongs_to :user

  validates :token_digest, :family_id, :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # @param [User] user
  # @param [String, nil] family_id nova família quando nil (login novo)
  # @param [String, nil] client
  # @return [Issued]
  def self.issue!(user:, family_id: nil, client: nil)
    token  = SecureRandom.urlsafe_base64(48)
    record = user.refresh_tokens.create!(
      token_digest: digest(token),
      family_id:    family_id || SecureRandom.uuid,
      client:       client,
      expires_at:   TTL.from_now
    )
    Issued.new(record: record, token: token)
  end

  # @param [String] token
  # @return [String]
  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # @param [String, nil] token
  # @return [RefreshToken, nil]
  def self.find_by_token(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def active?
    revoked_at.nil? && expires_at.future?
  end

  def revoke!
    return if revoked_at.present?

    update!(revoked_at: Time.current)
  end

  # @return [Integer] quantidade revogada
  def revoke_family!
    self.class.where(user_id: user_id, family_id: family_id, revoked_at: nil)
        .update_all(revoked_at: Time.current, updated_at: Time.current)
  end
end
