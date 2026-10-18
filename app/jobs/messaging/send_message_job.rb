# frozen_string_literal: true

module Messaging
  class SendMessageJob < ApplicationJob
    queue_as :default

    sidekiq_options retry: 5, dead: true

    rescue_from(StandardError) do |error|
      Alert.notify(
        "Messaging::SendMessageJob failed!",
        context: {
          job_name:        self.class.name,
          job_queue:       queue_name,
          job_executions:  executions,
          error_message:   error.message,
          error_backtrace: error.backtrace&.take(10)
        }
      )

      raise error
    end

    # @param [String] to
    # @param [String] body
    def perform(to, body)
      return if to.blank? || body.blank?

      ProviderFactory.build_outbound.send_message(to: to, body: body)
    end
  end
end
