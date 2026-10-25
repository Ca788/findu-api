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
      return unless deliverable?(notification)

      notification.user.device_tokens.find_each do |device|
        PushDeviceDeliveryJob.perform_later(notification.id, device.id)
      end
    end

    private

    def deliverable?(notification)
      return false unless notification&.channels&.include?("push")
      return false if notification.read?
      return false unless notification.user.notification_enabled?(notification.group, "push")

      true
    end
  end
end
