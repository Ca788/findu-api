# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      include ExceptionHandler

      before_action :skip_session_storage
      skip_before_action :verify_signed_out_user, only: :destroy

      def create
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)
        issued = RefreshToken.issue!(user: resource, client: client_platform)

        render json: ApiResponseSerializer.render(
          {
            user:          ::V1::UserSerializer.render_as_hash(resource),
            refresh_token: issued.token
          },
          message: "Logged in successfully."
        ), status: :ok
      end

      def destroy
        RefreshToken.find_by_token(params[:refresh_token])&.revoke_family!

        render json: ApiResponseSerializer.render(
          {},
          message: "Logged out successfully."
        ), status: :ok
      end

      private

      def skip_session_storage
        request.session_options[:skip] = true
      end

      def client_platform
        request.headers["X-Client-Platform"].to_s.presence
      end
    end
  end
end
