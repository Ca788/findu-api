# frozen_string_literal: true

module Notifications
  class NotifyDailyRegisterJob < ApplicationJob
    queue_as :default

    SLOTS = {
      "morning" => {
        title: "Hora de planejar o dia",
        body:  "Registra o que já saiu e o que ainda vai sair. Um áudio no chat resolve."
      },
      "noon" => {
        title: "Registra as despesas da manhã",
        body:  "Ainda dá tempo de anotar o que saiu hoje. Manda um áudio ou uma foto no chat."
      }
    }.freeze

    def perform(slot = "morning")
      slot = Array(slot).first.to_s
      copy = SLOTS[slot]
      return unless copy

      day = Date.current
      User.where(deleted_at: nil).find_each do |user|
        UseCase::Notifications::DispatchNotificationUseCase.new.call(
          user:       user,
          kind:       :daily_register,
          title:      copy[:title],
          body:       copy[:body],
          data:       { route: "/chat" },
          dedupe_key: "daily_register:#{day}:#{slot}"
        )
      end
    end
  end
end
