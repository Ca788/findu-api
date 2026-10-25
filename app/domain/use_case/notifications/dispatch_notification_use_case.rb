# frozen_string_literal: true

class UseCase::Notifications::DispatchNotificationUseCase
  IN_APP = "in_app"
  PUSH   = "push"

  def call(user:, kind:, title:, body: nil, data: {}, dedupe_key: nil)
    group    = Notification.group_for(kind)
    channels = Notification::CHANNELS.select { |channel| user.notification_enabled?(group, channel) }
    return nil if channels.empty?

    notification = persist(user, kind, title, body, data, dedupe_key, channels)
    return nil unless notification

    broadcast(user, notification) if channels.include?(IN_APP)
    ::Notifications::PushDeliveryJob.schedule(notification) if channels.include?(PUSH)
    notification
  end

  private

  def persist(user, kind, title, body, data, dedupe_key, channels)
    user.notifications.create!(
      kind:       kind.to_s,
      title:      title,
      body:       body,
      data:       data,
      dedupe_key: dedupe_key,
      channels:   channels
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def broadcast(user, notification)
    NotificationsChannel.broadcast_to(
      user,
      type:         "notification.created",
      notification: ::V1::NotificationSerializer.render_as_hash(notification),
      unread_count: user.notifications.unread.count
    )
  end
end
