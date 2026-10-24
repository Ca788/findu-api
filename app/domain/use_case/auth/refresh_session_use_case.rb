# frozen_string_literal: true

class UseCase::Auth::RefreshSessionUseCase
  class InvalidRefreshToken < StandardError; end

  Result = Struct.new(:user, :access_token, :refresh_token, keyword_init: true)

  # @param [String, nil] refresh_token token em claro enviado pelo cliente
  # @param [String, nil] client plataforma (web, android, ios) para auditoria
  # @raise [InvalidRefreshToken]
  # @return [Result]
  def call(refresh_token:, client: nil)
    record = RefreshToken.find_by_token(refresh_token)
    raise InvalidRefreshToken, "refresh token is invalid" if record.nil?

    result = RefreshToken.transaction do
      record.lock!
      next nil unless record.active? && record.user.deleted_at.nil?

      rotate(record, client)
    end
    return result if result

    record.revoke_family!
    raise InvalidRefreshToken, "refresh token is expired or was already used"
  end

  private

  # @param [RefreshToken] record token válido e travado
  # @param [String, nil] client
  # @return [Result]
  def rotate(record, client)
    record.update!(revoked_at: Time.current, last_used_at: Time.current)
    issued = RefreshToken.issue!(
      user:      record.user,
      family_id: record.family_id,
      client:    client.presence || record.client
    )

    Result.new(
      user:          record.user,
      access_token:  encode_access_token(record.user),
      refresh_token: issued.token
    )
  end

  # @param [User] user
  # @return [String]
  def encode_access_token(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end
end
