# frozen_string_literal: true

module Notifications
  class NotifyIdleUsersJob < ApplicationJob
    queue_as :default

    IDLE_DAYS = 7

    def perform
      cutoff = IDLE_DAYS.days.ago
      week   = Date.current.strftime("%G-W%V")

      User.where(deleted_at: nil).where("users.created_at < ?", cutoff).find_each do |user|
        next if user.transactions.where("created_at >= ?", cutoff).exists?

        UseCase::Notifications::DispatchNotificationUseCase.new.call(
          user:       user,
          kind:       :idle_reminder,
          title:      "Faz #{IDLE_DAYS} dias que você não registra nada",
          body:       "Mande um áudio ou uma foto do comprovante no chat que eu lanço pra você.",
          data:       { route: "/chat" },
          dedupe_key: "idle_reminder:#{week}"
        )
      end
    end
  end
end
