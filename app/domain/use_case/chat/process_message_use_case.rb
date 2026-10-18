# frozen_string_literal: true

class UseCase::Chat::ProcessMessageUseCase
  RECEIPT_CONFIDENCE_THRESHOLD = 0.45

  SideEffect = Struct.new(:payload, :fact, keyword_init: true)

  def initialize(transcriber: UseCase::Chat::TranscribeMessageUseCase.new,
                 receipt_extractor: UseCase::Chat::ExtractReceiptUseCase.new,
                 answerer: UseCase::Chat::AnswerConversationallyUseCase.new,
                 agent_selector: UseCase::Chat::SelectAgentUseCase.new)
    @transcriber       = transcriber
    @receipt_extractor = receipt_extractor
    @answerer          = answerer
    @agent_selector    = agent_selector
  end

  # @param [Chat::Message] message
  # @param [Hash] timings
  # @return [Chat::Message] assistant reply
  def call(message:, timings: {})
    timings = timings.stringify_keys
    message.update!(status: "processing")
    message.conversation.broadcast_message!(message)

    transcription_metadata = transcribe_if_audio_measured(message, timings)
    receipt_side_effects   = extract_receipts_measured(message, timings)

    payload = merge_payloads(receipt_side_effects).merge(
      transcription: transcription_metadata
    ).compact

    finalize_user_message(message, payload: payload)

    selection = select_agent_measured(message, timings)
    reply = @answerer.call(
      user_message: message,
      side_facts:   receipt_side_effects.map(&:fact),
      agent:        selection.agent,
      timings:      timings
    )
    Support::ChatPipelineTiming.persist(message, timings)
    reply
  rescue StandardError => e
    message.update!(
      status: "failed",
      error:  { class: e.class.name, message: e.message }
    )
    Support::ChatPipelineTiming.persist(message, timings)
    message.conversation.broadcast_message!(message)
    raise
  end

  private

  def transcribe_if_audio_measured(message, timings)
    return transcribe_if_audio(message) unless message.kind_audio?

    result, elapsed = Support::ChatPipelineTiming.measure(
      "transcribe",
      message_id: message.id,
      user_id:    message.user_id
    ) { transcribe_if_audio(message) }
    timings["transcribe_ms"] = elapsed
    result
  end

  def extract_receipts_measured(message, timings)
    return run_receipt_side_effects(message) unless receipt_extraction_needed?(message)

    result, elapsed = Support::ChatPipelineTiming.measure(
      "receipt",
      message_id: message.id,
      user_id:    message.user_id
    ) { run_receipt_side_effects(message) }
    timings["receipt_ms"] = elapsed
    result
  end

  def receipt_extraction_needed?(message)
    existing = message.payload.is_a?(Hash) && message.payload["receipt_candidates"]
    existing.present? || message.image_attachments.any?
  end

  def select_agent_measured(message, timings)
    timings["intent_llm"] = false

    result, elapsed = Support::ChatPipelineTiming.measure(
      "intent",
      message_id: message.id,
      user_id:    message.user_id,
      intent_llm: timings["intent_llm"]
    ) do
      @agent_selector.call(
        text:         message.body,
        forced_agent: message.conversation.agent_id
      )
    end
    timings["intent_ms"] = elapsed
    timings["intent"] = result.intent
    result
  end

  def transcribe_if_audio(message)
    return nil unless message.kind_audio?

    transcription = @transcriber.call(message: message)
    {
      confidence: transcription.confidence,
      provider:   transcription.metadata && transcription.metadata[:provider],
      model:      transcription.metadata && transcription.metadata[:model]
    }.compact
  end

  def run_receipt_side_effects(message)
    existing = message.payload.is_a?(Hash) && message.payload["receipt_candidates"]
    return rebuild_side_effects_from_payload(existing) if existing.present?
    return [] unless message.image_attachments.any?

    receipts = @receipt_extractor.call(message: message)
    receipts.filter_map do |receipt|
      next nil if receipt.confidence.to_f < RECEIPT_CONFIDENCE_THRESHOLD
      next nil unless usable_receipt_amount?(receipt)

      candidate = receipt_candidate(receipt)
      SideEffect.new(
        payload: { receipt_candidates: [candidate], receipt_awaiting_confirmation: true },
        fact:    confirmation_fact(receipt)
      )
    end
  end

  def receipt_candidate(receipt)
    {
      amount:             receipt.amount&.to_s,
      total_amount:       receipt.total_amount&.to_s,
      monthly_amount:     receipt.monthly_amount&.to_s,
      total_installments: receipt.total_installments,
      is_installment:     !!receipt.is_installment,
      occurred_at:        receipt.occurred_at&.iso8601,
      description:        receipt.description,
      transaction_type:   receipt.transaction_type,
      confidence:         receipt.confidence
    }.compact
  end

  def confirmation_fact(receipt)
    type = receipt.transaction_type.to_s == "income" ? "receita" : "despesa"
    if receipt.is_installment && receipt.total_installments.to_i > 1
      count   = receipt.total_installments.to_i
      total   = decimal_or_nil(receipt.total_amount) || decimal_or_nil(receipt.amount)
      monthly = decimal_or_nil(receipt.monthly_amount)
      monthly ||= (total / count) if total && count.positive?
      [
        "Extraí um PARCELAMENTO do recibo (ainda NÃO registrado).",
        "Descrição: #{receipt.description.presence || 'sem descrição'}.",
        "#{count}x de #{Formatters::Brl.call(monthly)} (total #{Formatters::Brl.call(total)}).",
        "Tipo sugerido: #{type}.",
        "NÃO chame tools ainda. Mostre este resumo e pergunte se o usuário confirma o parcelamento.",
        "Só após confirmação explícita, use register_installment_plan (não register_transaction)."
      ].join(" ")
    else
      amount = decimal_or_nil(receipt.total_amount) || decimal_or_nil(receipt.amount)
      [
        "Extraí um lançamento do recibo (ainda NÃO registrado).",
        "#{type.capitalize} de #{Formatters::Brl.call(amount)}",
        "#{receipt.description.present? ? "(#{receipt.description})" : ''}.",
        "NÃO chame tools ainda. Mostre o resumo e pergunte se o usuário confirma o registro.",
        "Só após confirmação explícita, use register_transaction."
      ].join(" ")
    end
  end

  def usable_receipt_amount?(receipt)
    [receipt.amount, receipt.total_amount, receipt.monthly_amount].any? do |value|
      amount = decimal_or_nil(value)
      amount&.positive?
    end
  end

  def decimal_or_nil(value)
    return nil if value.blank?

    amount = value.to_d
    return nil if amount.zero?

    amount
  rescue ArgumentError
    nil
  end

  def rebuild_side_effects_from_payload(candidates)
    Array(candidates).filter_map do |candidate|
      next nil unless candidate.is_a?(Hash)

      receipt = UseCase::Chat::ExtractReceiptUseCase::Receipt.new(
        amount:             candidate["amount"],
        total_amount:       candidate["total_amount"],
        monthly_amount:     candidate["monthly_amount"],
        total_installments: candidate["total_installments"],
        is_installment:     candidate["is_installment"],
        occurred_at:        candidate["occurred_at"],
        description:        candidate["description"],
        transaction_type:   candidate["transaction_type"] || "expense",
        confidence:         candidate["confidence"].to_f,
        raw_text:           ""
      )
      SideEffect.new(
        payload: { receipt_candidates: [candidate], receipt_awaiting_confirmation: true },
        fact:    confirmation_fact(receipt)
      )
    end
  end

  def merge_payloads(side_effects)
    side_effects.each_with_object({}) do |effect, acc|
      candidates = Array(acc[:receipt_candidates]) + Array(effect.payload[:receipt_candidates])
      acc.merge!(effect.payload)
      acc[:receipt_candidates] = candidates if candidates.any?
    end
  end

  def finalize_user_message(message, payload:)
    message.update!(status: "completed", payload: payload)
    message.conversation.broadcast_message!(message)
  end
end
