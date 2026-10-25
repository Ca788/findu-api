# frozen_string_literal: true

module Notifications
  class PurgeStaleDeviceTokensJob < ApplicationJob
    queue_as :default

    STALE_AFTER = 60.days

    def perform
      DeviceToken.where("last_seen_at < ?", STALE_AFTER.ago).delete_all
    end
  end
end
