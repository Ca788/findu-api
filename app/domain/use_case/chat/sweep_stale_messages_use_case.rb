# frozen_string_literal: true

# Mensagem em "processing" só sai desse estado pelo processo que a criou. Se o
# worker morre no meio do stream (deploy, OOM, SIGKILL), nada reverte o status e
# o chat fica girando para sempre. Este sweep fecha essas mensagens.
class UseCase::Chat::SweepStaleMessagesUseCase
  # O padrão precisa ficar acima do pior caso legítimo de um turno de chat:
  # transcrição, extração, intenção e agente, cada um até RUBY_LLM_TIMEOUT e
  # multiplicado pela cadeia de modelos do ModelFallback.
  STALE_AFTER_MINUTES = ENV.fetch("CHAT_STALE_MESSAGE_MINUTES", "15").to_i
  BATCH_SIZE          = 200

  STALE_ERROR = {
    "class"   => "Chat::StaleMessage",
    "message" => "Processamento interrompido antes de terminar."
  }.freeze

  # @param [ActiveSupport::Duration]
  # @return [Integer] quantidade de mensagens encerradas
  def call(stale_after: STALE_AFTER_MINUTES.minutes)
    cutoff = Time.current - stale_after

    released = 0
    stale_scope(cutoff).find_each(batch_size: BATCH_SIZE) do |message|
      released += 1 if release(message)
    end

    released
  end

  private

  # @param [ActiveSupport::TimeWithZone]
  # @return [ActiveRecord::Relation]
  def stale_scope(cutoff)
    Chat::Message.not_deleted
                 .where(status: "processing")
                 .where(updated_at: ..cutoff)
  end

  # O claim é condicionado ao status para que dois sweeps concorrentes, ou um
  # sweep e o próprio job terminando, não encerrem a mesma mensagem duas vezes.
  # @param [Chat::Message]
  # @return [Boolean]
  def release(message)
    claimed = Chat::Message.where(id: message.id, status: "processing")
                           .update_all(release_attributes(message))
    return false if claimed.zero?

    message.reload
    message.conversation.broadcast_message!(message)
    Rails.logger.warn("[SweepStaleMessagesUseCase] released stale message #{message.id}")
    true
  end

  # @param [Chat::Message]
  # @return [Hash]
  def release_attributes(message)
    attributes = { status: "failed", error: STALE_ERROR, updated_at: Time.current }
    return attributes unless message.role_assistant? && message.body.blank?

    attributes.merge(body: UseCase::Chat::AnswerConversationallyUseCase::FALLBACK_BODY)
  end
end
