# frozen_string_literal: true

class Chat::ProcessMessageJob < ApplicationJob
  queue_as :chat

  sidekiq_options retry: 3, dead: true

  rescue_from(StandardError) do |error|
    message = arguments[0]

    context_info = {
      message_id:       message&.id,
      conversation_id:  message&.conversation_id,
      user_id:          message&.user_id,
      kind:             message&.kind,
      job_name:         self.class.name,
      job_arguments:    self.arguments,
      error_message:    error.message,
      error_backtrace:  error.backtrace&.take(10),
      job_scheduled_at: self.scheduled_at,
      job_executions:   self.executions,
      job_queue:        self.queue_name
    }

    Alert.notify(
      "Chat::ProcessMessageJob failed!",
      context: context_info
    )

    raise error
  end

  # @param [Chat::Message] message
  def perform(message)
    timings = nil
    started = nil
    timings = Support::ChatPipelineTiming.existing(message)
    timings["queue_wait_ms"] = Support::ChatPipelineTiming.queue_wait_ms(timings["enqueued_at"])
    started = Support::ChatPipelineTiming.monotonic

    UseCase::Chat::ProcessMessageUseCase.new.call(message: message, timings: timings)
  ensure
    if message && timings
      timings["total_job_ms"] = Support::ChatPipelineTiming.elapsed_ms(started) if started
      Support::ChatPipelineTiming.persist(message, timings)
    end
  end
end
