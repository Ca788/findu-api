# frozen_string_literal: true

class UseCase::Chat::CreateMessageUseCase
  # @param [Chat::Conversation]
  # @param [User]
  # @param [String, nil]
  # @param [ActionDispatch::Http::UploadedFile, nil]
  # @param [Array<ActionDispatch::Http::UploadedFile>]
  # @param [String, nil]
  # @return [Chat::Message]
  def call(conversation:, user:, body: nil, audio: nil, attachments: [], client_message_id: nil)
    attachments = Array(attachments).compact_blank
    if body.blank? && audio.blank? && attachments.empty?
      raise ArgumentError, "body, audio or attachments are required"
    end

    if client_message_id.present?
      existing = user.chat_messages.find_by(client_message_id: client_message_id)
      return existing if existing
    end

    kind = audio.present? ? "audio" : "text"
    started = Support::ChatPipelineTiming.monotonic

    message = conversation.messages.new(
      user:              user,
      role:              "user",
      kind:              kind,
      status:            "pending",
      body:              body,
      client_message_id: client_message_id
    )

    message.audio.attach(audio) if audio.present?
    message.attachments.attach(attachments) if attachments.any?

    message.save!
    assign_title_from_first_message!(conversation, message)

    conversation.broadcast_message!(message)
    Chat::ProcessMessageJob.perform_later(message)

    Support::ChatPipelineTiming.persist(
      message,
      "enqueued_at" => Time.current.iso8601(3),
      "create_ms"   => Support::ChatPipelineTiming.elapsed_ms(started)
    )

    message
  end

  private

  def assign_title_from_first_message!(conversation, message)
    return if conversation.title.present?
    return unless conversation.messages.where(role: "user").limit(2).count == 1

    title =
      if message.body.present?
        message.body.to_s.squish.truncate(80)
      elsif message.kind_audio?
        "Áudio"
      elsif message.image_attachments.any?
        "Imagem"
      elsif message.attachments.attached?
        "Anexo"
      end

    return if title.blank?

    conversation.update!(title: title)
    conversation.broadcast_inbox!
  end
end
