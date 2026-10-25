# frozen_string_literal: true

module Notifications
  class NotifyEndingInstallmentsJob < ApplicationJob
    queue_as :default

    def perform
      User.where(deleted_at: nil).find_each do |user|
        UseCase::Notifications::NotifyEndingInstallmentsUseCase.new.call(user: user)
      end
    end
  end
end
