# frozen_string_literal: true

module Api
  module V1
    class TokensController < Api::BaseController
      skip_before_action :authenticate_user!, only: [:refresh]
      skip_before_action :set_user, only: [:refresh]

      rescue_from UseCase::Auth::RefreshSessionUseCase::InvalidRefreshToken do
        render json: ApiResponseSerializer.error(ErrorMapper.unauthorized), status: :unauthorized
      end

      def refresh
        result = UseCase::Auth::RefreshSessionUseCase.new.call(
          refresh_token: params.require(:refresh_token),
          client:        request.headers["X-Client-Platform"].to_s.presence
        )

        response.set_header("Authorization", "Bearer #{result.access_token}")

        render json: ApiResponseSerializer.render(
          {
            user:          ::V1::UserSerializer.render_as_hash(result.user),
            refresh_token: result.refresh_token
          },
          message: "Session refreshed."
        ), status: :ok
      end
    end
  end
end
