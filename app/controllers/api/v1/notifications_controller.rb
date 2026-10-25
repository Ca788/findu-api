# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < Api::BaseController
      def index
        scope = @user.notifications.by_kind(params[:kind]).recent
        scope = scope.unread if ActiveModel::Type::Boolean.new.cast(params[:unread])
        notifications = scope.page(page_param).per(per_page_param(default: 20))

        render json: ApiResponseSerializer.render_data_array(
          notifications,
          serializer:      ::V1::NotificationSerializer,
          serializer_view: serializer_view_param,
          pagination:      pagination_for(notifications),
          metadata:        { unread_count: @user.notifications.unread.count }
        ), status: :ok
      end

      def unread_count
        render json: ApiResponseSerializer.render(
          { unread_count: @user.notifications.unread.count }
        ), status: :ok
      end

      def read
        UseCase::Notifications::MarkNotificationsReadUseCase.new.call(user: @user, ids: [params[:id]])

        render json: ApiResponseSerializer.render(
          @user.notifications.find(params[:id]),
          serializer: ::V1::NotificationSerializer
        ), status: :ok
      end

      def read_all
        updated = UseCase::Notifications::MarkNotificationsReadUseCase.new.call(user: @user)

        render json: ApiResponseSerializer.render(
          { updated: updated, unread_count: 0 },
          message: "Notifications marked as read."
        ), status: :ok
      end

      def preferences
        render json: ApiResponseSerializer.render(
          { groups: @user.notification_preferences }
        ), status: :ok
      end

      def update_preferences
        groups = UseCase::Notifications::UpdateNotificationPreferencesUseCase.new.call(
          user:   @user,
          groups: preferences_params
        )

        render json: ApiResponseSerializer.render(
          { groups: groups },
          message: "Preferences updated."
        ), status: :ok
      end

      def register_device
        device = DeviceToken.register(
          user:     @user,
          token:    params.require(:token),
          platform: params[:platform].presence || "android"
        )

        render json: ApiResponseSerializer.render(
          { id: device.id, platform: device.platform, last_seen_at: device.last_seen_at }
        ), status: :ok
      end

      def unregister_device
        removed = @user.device_tokens.where(token: params.require(:token)).delete_all

        render json: ApiResponseSerializer.render({ removed: removed }), status: :ok
      end

      private

      def preferences_params
        params.require(:groups).permit(
          Notification::GROUPS.values.index_with { Notification::CHANNELS }
        ).to_h
      end
    end
  end
end
