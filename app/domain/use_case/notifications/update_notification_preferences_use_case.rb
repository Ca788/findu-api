# frozen_string_literal: true

class UseCase::Notifications::UpdateNotificationPreferencesUseCase
  def call(user:, groups:)
    stored = user.notification_preferences

    groups.to_h.each do |group, channels|
      next unless stored.key?(group.to_s)

      channels.to_h.each do |channel, enabled|
        next unless Notification::CHANNELS.include?(channel.to_s)

        stored[group.to_s][channel.to_s] = ActiveModel::Type::Boolean.new.cast(enabled) == true
      end
    end

    settings = (user.settings || {}).deep_dup
    settings["notifications"] = (settings["notifications"] || {}).merge("groups" => stored)
    user.update!(settings: settings)

    user.notification_preferences
  end
end
