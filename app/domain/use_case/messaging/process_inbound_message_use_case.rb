# frozen_string_literal: true

class UseCase::Messaging::ProcessInboundMessageUseCase
  CONFIDENCE_THRESHOLD = 0.5

  # @param [Messaging::Provider]
  # @param [UseCase::Messaging::ExtractTransactionFromMessageUseCase]
  # @param [UseCase::Financial::Transaction::CreateTransactionUseCase]
  # @param [UseCase::Financial::Category::FindOrCreateByNameUseCase]
  # @param [UseCase::Artifact::CreateArtifactUseCase]
  # @param [UseCase::Artifact::ExtractArtifactDataUseCase]
  # @param [UseCase::Artifact::CreateTransactionFromArtifactUseCase]
  def initialize(provider:,
                 extractor: UseCase::Messaging::ExtractTransactionFromMessageUseCase.new,
                 transaction_creator: UseCase::Financial::Transaction::CreateTransactionUseCase.new,
                 category_finder: UseCase::Financial::Category::FindOrCreateByNameUseCase.new,
                 artifact_creator: UseCase::Artifact::CreateArtifactUseCase.new,
                 artifact_extractor: UseCase::Artifact::ExtractArtifactDataUseCase.new,
                 artifact_transaction_creator: UseCase::Artifact::CreateTransactionFromArtifactUseCase.new)
    @provider                     = provider
    @extractor                    = extractor
    @transaction_creator          = transaction_creator
    @category_finder              = category_finder
    @artifact_creator             = artifact_creator
    @artifact_extractor           = artifact_extractor
    @artifact_transaction_creator = artifact_transaction_creator
  end

  # @param [Messaging::Message]
  # @return [void]
  def call(message:)
    user = User.find_by(phone: message.from)

    unless user
      @provider.send_message(to: message.reply_to, body: reply_user_not_found)
      return
    end

    if message.media.present?
      handle_image(user, message)
    else
      handle_text(user, message)
    end
  end

  private

  def handle_image(user, message)
    attachment = @provider.fetch_media(**message.media.first)
    artifact   = @artifact_creator.call(
      user:          user,
      file:          attachment,
      artifact_type: "receipt",
      source:        "whatsapp",
      raw_data:      { "reply_to" => message.reply_to },
      process_async: false
    )

    reply = register_receipt(artifact)
    Messaging::SendMessageJob.perform_later(message.reply_to, reply)
  end

  # Extração e lançamento ficam na própria request: uma chamada ao modelo, sem
  # retry que a repita. A resposta é sempre enfileirada, inclusive em falha.
  def register_receipt(artifact)
    artifact = @artifact_extractor.call(artifact: artifact)
    return reply_receipt_needs_review if artifact.needs_review?

    transaction = @artifact_transaction_creator.call(artifact: artifact)
    Chat::Replies::Formatter.transaction(transaction)
  rescue StandardError => e
    Rails.logger.error(
      "[ProcessInboundMessageUseCase] artifact ##{artifact.id} failed: #{e.class}: #{e.message}"
    )
    reply_receipt_error
  end

  def handle_text(user, message)
    result = @extractor.call(message: message)

    if result.amount.blank? || result.confidence < CONFIDENCE_THRESHOLD
      @provider.send_message(to: message.reply_to, body: reply_parse_error)
      return
    end

    category    = @category_finder.call(user: user, name: result.description)
    transaction = @transaction_creator.call(
      user:             user,
      amount:           result.amount,
      transaction_type: result.transaction_type,
      description:      result.description,
      occurred_at:      result.occurred_at || Time.current,
      category_id:      category&.id
    )

    @provider.send_message(to: message.reply_to, body: Chat::Replies::Formatter.transaction(transaction))
  end

  def reply_user_not_found
    "Número não cadastrado. Acesse o app para criar sua conta."
  end

  def reply_parse_error
    'Não entendi. Tente: "gastei R$50 no mercado" ou "recebi R$200 de salário".'
  end

  def reply_receipt_needs_review
    "Recibo recebido, mas não consegui confirmar os dados. Confira no app para registrar."
  end

  def reply_receipt_error
    "Recibo recebido, mas não consegui ler os dados. Tente uma foto mais nítida ou registre no app."
  end
end
