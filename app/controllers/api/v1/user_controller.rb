# frozen_string_literal: true

module Api
  module V1
    class UserController < Api::BaseController
      include ExceptionHandler

      skip_before_action :authenticate_user!, only: [:create]
      skip_before_action :set_user, only: [:create]

      def show
        render json: ApiResponseSerializer.render(
          { user: ::V1::UserSerializer.render_as_hash(@user) }
        ), status: :ok
      end

      def create
        result = UseCase::User::CreateUserUseCase.new.call(
          name: user_params[:name],
          email: user_params[:email],
          password: user_params[:password],
          password_confirmation: user_params[:password_confirmation],
          phone: user_params[:phone],
          client: request.headers["X-Client-Platform"].to_s.presence
        )

        response.set_header("Authorization", "Bearer #{result.token}")

        render json: ApiResponseSerializer.render(
          {
            user:          ::V1::UserSerializer.render_as_hash(result.user),
            refresh_token: result.refresh_token
          },
          message: "User created successfully."
        ), status: :created
      end

      def update
        updated = UseCase::User::UpdateUserProfileUseCase.new.call(
          user: @user,
          attributes: update_profile_params.to_h,
          avatar: update_avatar_param,
          remove_avatar: update_remove_avatar_param
        )

        render json: ApiResponseSerializer.render(
          { user: ::V1::UserSerializer.render_as_hash(updated) },
          message: "Profile updated successfully."
        ), status: :ok
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
      end

      def update_profile_params
        params.require(:user).permit(:name, :phone)
      end

      def update_avatar_param
        params.dig(:user, :avatar)
      end

      def update_remove_avatar_param
        params.dig(:user, :remove_avatar)
      end
    end
  end
end
