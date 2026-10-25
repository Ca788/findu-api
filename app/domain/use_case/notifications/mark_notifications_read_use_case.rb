# frozen_string_literal: true

class UseCase::Notifications::MarkNotificationsReadUseCase
  def call(user:, ids: nil)
    scope = user.notifications.unread
    scope = scope.where(id: ids) if ids
    updated = scope.update_all(read_at: Time.current, updated_at: Time.current)

    broadcast(user) if updated.positive?
    updated
  end

  private

  def broadcast(user)
    NotificationsChannel.broadcast_to(
      user,
      type:         "notifications.read",
      unread_count: user.notifications.unread.count
    )
  end
end
