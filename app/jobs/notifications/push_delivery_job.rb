# frozen_string_literal: true

module Notifications
  class PushDeliveryJob < ApplicationJob
    queue_as :default

    QUIET_START = 22
    QUIET_END   = 8

    def self.schedule(notification)
      return unless Push::FcmClient.configured?
      return unless notification.user.device_tokens.exists?

      set(wait_until: deliver_at(Time.current)).perform_later(notification.id)
    end

    def self.deliver_at(now)
      return now if now.hour >= QUIET_END && now.hour < QUIET_START

      next_window = now.hour >= QUIET_START ? now.tomorrow : now
      next_window.change(hour: QUIET_END)
    end

    def perform(notification_id)
      notification = Notification.find_by(id: notification_id)
      return unless notification&.channels&.include?("push")

      client = Push::FcmClient.new
      notification.user.device_tokens.find_each do |device|
        deliver(client, device, notification)
      end
    end

    private

    def deliver(client, device, notification)
      client.send_to_token(
        token: device.token,
        title: notification.title,
        body:  notification.body,
        data:  notification.data.merge(notification_id: notification.id, kind: notification.kind)
      )
    rescue Push::FcmClient::Unregistered
      device.destroy
    rescue Push::FcmClient::Error => e
      Rails.logger.warn("[push] #{device.platform} #{notification.kind} failed: #{e.message}")
    end
  end
end
