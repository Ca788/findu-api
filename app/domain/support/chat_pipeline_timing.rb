# frozen_string_literal: true

module Support
  # Mede estágios do pipeline de chat sem alterar o comportamento.
  # Grava durações em `chat_messages.payload["timings"]` e emite
  # ActiveSupport::Notifications. Não inclui prompt nem corpo de mensagem.
  module ChatPipelineTiming
    NOTIFICATION_PREFIX = "chat.pipeline"

    module_function

    # @param [String] stage
    # @param [Hash] payload metadados sem PII
    # @return [Array(Object, Integer)] [resultado, duração em ms]
    def measure(stage, payload = {})
      started = monotonic
      name = "#{NOTIFICATION_PREFIX}.#{stage}"
      result = trace(name, payload) { yield }
      elapsed = elapsed_ms(started)
      notify(name, payload, elapsed)
      [result, elapsed]
    rescue StandardError
      notify("#{NOTIFICATION_PREFIX}.#{stage}", payload, elapsed_ms(started), error: true)
      raise
    end

    # @return [Float]
    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # @param [Float] started
    # @param [Float, nil] ended
    # @return [Integer]
    def elapsed_ms(started, ended: nil)
      finish = ended || monotonic
      ((finish - started) * 1000).round
    end

    # @param [Chat::Message, nil]
    # @return [Hash]
    def existing(message)
      return {} if message.nil?

      payload = (message.payload || {}).deep_stringify_keys
      (payload["timings"] || {}).deep_stringify_keys
    end

    # @param [String, nil]
    # @return [Integer, nil]
    def queue_wait_ms(enqueued_at)
      return nil if enqueued_at.blank?

      parsed = Time.iso8601(enqueued_at.to_s)
      wait = ((Time.current - parsed) * 1000).round
      [wait, 0].max
    rescue ArgumentError, TypeError
      nil
    end

    # @param [Chat::Message, nil]
    # @param [Hash] timings
    # @return [void]
    def persist(message, timings)
      return if message.nil? || !message.persisted? || timings.blank?

      payload = (message.payload || {}).deep_stringify_keys
      payload["timings"] = (payload["timings"] || {}).merge(compact_timings(timings))
      message.update!(payload: payload)
    end

    # @param [Hash] timings
    # @return [Hash]
    def compact_timings(timings)
      timings.stringify_keys.reject { |_key, value| value.nil? }
    end

    def notify(name, payload, duration_ms, error: false)
      ActiveSupport::Notifications.instrument(
        name,
        compact_timings(payload).merge("duration_ms" => duration_ms, "error" => error)
      )
    end

    def trace(name, payload)
      return yield unless datadog_enabled?

      Datadog::Tracing.trace(
        "chat.pipeline",
        resource: name,
        tags: compact_timings(payload)
      ) { yield }
    end

    def datadog_enabled?
      defined?(Datadog::Tracing) && Datadog::Tracing.respond_to?(:trace)
    end
  end
end
