# frozen_string_literal: true

class Chat::SweepStaleMessagesJob < ApplicationJob
  queue_as :default

  def perform
    released = UseCase::Chat::SweepStaleMessagesUseCase.new.call
    return if released.zero?

    Rails.logger.warn("[Chat::SweepStaleMessagesJob] released #{released} stale message(s)")
  end
end
