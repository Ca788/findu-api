# frozen_string_literal: true

module Notifications
  class PushDeviceDeliveryJob < ApplicationJob
    queue_as :default

    retry_on Push::FcmClient::Transient, wait: :polynomially_longer, attempts: 5 do |job, error|
      notification_id, device_id = job.arguments
      Alert.notify(
        "[push] transient exhausted",
        context: { notification_id: notification_id, device_id: device_id, error: error.message }
      )
    end

    discard_on Push::FcmClient::Unregistered do |job, _error|
      DeviceToken.find_by(id: job.arguments.second)&.destroy
    end

    def perform(notification_id, device_id)
      notification = Notification.find_by(id: notification_id)
      device       = DeviceToken.find_by(id: device_id)
      return unless notification && device
      return unless Push::FcmClient.configured?
      return unless notification.channels.include?("push")
      return if notification.read?
      return unless notification.user.notification_enabled?(notification.group, "push")

      Push::FcmClient.new.send_to_token(
        token:        device.token,
        title:        notification.title,
        body:         notification.body,
        data:         notification.data.merge(notification_id: notification.id, kind: notification.kind),
        platform:     device.platform,
        collapse_key: notification.kind
      )
    rescue Push::FcmClient::Error => e
      raise if e.is_a?(Push::FcmClient::Transient) || e.is_a?(Push::FcmClient::Unregistered)

      Alert.notify(
        "[push] delivery failed",
        context: {
          notification_id: notification_id,
          device_id:       device_id,
          kind:            notification&.kind,
          platform:        device&.platform,
          error:           e.message
        }
      )
    end
  end
end
