# frozen_string_literal: true

class UseCase::User::CreateUserUseCase
  Result = Struct.new(:user, :token, :refresh_token, keyword_init: true)

  # @param [String] name
  # @param [String] email
  # @param [String] password
  # @param [String] password_confirmation
  # @param [String] phone
  # @param [String, nil] client plataforma do cliente (web, android, ios)
  # @return [Result]
  def call(name:, email:, password:, password_confirmation:, phone: nil, client: nil)
    user = User.create!(
      name: name,
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      phone: phone
    )

    token   = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    refresh = RefreshToken.issue!(user: user, client: client)

    Result.new(user: user, token: token, refresh_token: refresh.token)
  end
end
