# frozen_string_literal: true

class UseCase::Chat::AnswerConversationallyUseCase
  class StreamAlreadyStartedError < StandardError; end

  HISTORY_LIMIT          = 20
  STREAM_FLUSH_SECONDS   = ENV.fetch("CHAT_STREAM_FLUSH_SECONDS", "0.35").to_f
  STREAM_FLUSH_MIN_CHARS = ENV.fetch("CHAT_STREAM_FLUSH_MIN_CHARS", "24").to_i
  FALLBACK_BODY          = "Desculpe, tive um problema agora. Pode repetir?"
  RATE_LIMIT_BODY        = "Atingi o limite de requisições do modelo de IA agora. " \
                           "Tente de novo em alguns segundos — ou aumente a cota do Gemini."

  # @param [UseCase::Chat::BuildUserContextUseCase]
  # @param [Llm::Prompts::ChatAgentPromptBuilder]
  # @param [Array<String>]
  def initialize(context_builder: UseCase::Chat::BuildUserContextUseCase.new,
                 prompt_builder: Llm::Prompts::ChatAgentPromptBuilder.new,
                 models: Llm::Models.chain("CHAT_AGENT_MODEL"))
    @context_builder = context_builder
    @prompt_builder  = prompt_builder
    @models          = models
  end

  # @param [Chat::Message]
  # @param [Array<String>]
  # @param [Llm::Agents::Agent, nil]
  # @param [Hash] timings
  # @return [Chat::Message]
  def call(user_message:, side_facts: [], agent: nil, timings: {})
    timings        = timings.stringify_keys
    user           = user_message.user
    selected_agent = agent || Llm::Agents::Registry::DEFAULT
    reply          = build_streaming_reply(user_message)
    models         = Llm::Models.prefer(user_message.conversation.model_id, "CHAT_AGENT_MODEL")
    timings["model"] = models.first

    context, context_ms = Support::ChatPipelineTiming.measure(
      "context",
      message_id: user_message.id,
      user_id:    user.id
    ) { @context_builder.call(user: user, timings: timings) }
    timings["context_ms"] = context_ms

    system_text, prompt_ms = Support::ChatPipelineTiming.measure(
      "prompt",
      message_id: user_message.id,
      user_id:    user.id
    ) { @prompt_builder.call(context: context, side_facts: side_facts, agent: selected_agent) }
    timings["prompt_ms"] = prompt_ms
    timings["prompt_chars"] = system_text.to_s.length

    history = history_messages(user_message)
    timings["history_messages"] = history.size
    attachment_paths =
      if side_facts.any? { |fact| fact.to_s.include?("NÃO registrado") }
        []
      else
        resolve_attachment_paths(user_message)
      end

    final_body = Llm::ModelFallback.with_fallback(models) do |model|
      timings["model"] = model
      chat = build_chat(model: model, system_text: system_text, history: history, user: user, agent: selected_agent)
      stream_response(
        chat: chat,
        user_message: user_message,
        reply: reply,
        attachment_paths: attachment_paths,
        timings: timings
      )
    end

    finalize_reply(reply, body: final_body, timings: timings)
    reply
  rescue RubyLLM::RateLimitError, StreamAlreadyStartedError => e
    Rails.logger.warn("[AnswerConversationallyUseCase] rate limit: #{e.message}")
    finalize_reply(reply, body: RATE_LIMIT_BODY, timings: timings) if reply
    reply
  rescue StandardError => e
    Rails.logger.error("[AnswerConversationallyUseCase] #{e.class}: #{e.message}")
    finalize_reply(reply, body: FALLBACK_BODY, error: { class: e.class.name, message: e.message }, timings: timings) if reply
    reply
  end

  private

  def build_chat(model:, system_text:, history:, user:, agent:)
    chat = Llm::GeminiChat.for(model)
                          .with_instructions(system_text)
                          .with_tools(*agent.build_tools(user))
    history.each { |m| chat.add_message(role: m.role.to_sym, content: m.body.to_s) }
    chat
  end

  def build_streaming_reply(user_message)
    reply = user_message.conversation.messages.create!(
      user:           user_message.user,
      role:           "assistant",
      kind:           "text",
      status:         "processing",
      body:           "",
      parent_message: user_message
    )
    user_message.conversation.broadcast_message!(reply)
    reply
  end

  def history_messages(user_message)
    user_message.conversation.messages
                .where(status: "completed")
                .where.not(id: user_message.id)
                .where(role: %w[user assistant])
                .where.not(body: [nil, ""])
                .order(created_at: :asc)
                .last(HISTORY_LIMIT)
  end

  def stream_response(chat:, user_message:, reply:, attachment_paths: [], timings: {})
    buffer        = +""
    flushed_upto  = 0
    last_flush_at = Time.current
    gen_started   = Support::ChatPipelineTiming.monotonic
    first_token_at = nil
    tool_rounds    = 0

    if chat.respond_to?(:on_tool_call)
      chat.on_tool_call { tool_rounds += 1 }
    end

    chat.ask(user_message.body.to_s, with: attachment_paths) do |chunk|
      text = chunk.content.to_s
      buffer << text
      first_token_at ||= Support::ChatPipelineTiming.monotonic if text.present?
      now = Time.current
      pending = buffer.length - flushed_upto
      next unless pending >= STREAM_FLUSH_MIN_CHARS && (now - last_flush_at) >= STREAM_FLUSH_SECONDS

      flush_delta!(reply, buffer, flushed_upto)
      flushed_upto  = buffer.length
      last_flush_at = now
    end

    flush_delta!(reply, buffer, flushed_upto) if buffer.length > flushed_upto
    record_generation_timings(timings, chat, gen_started, first_token_at, tool_rounds)
    buffer.presence || FALLBACK_BODY
  rescue RubyLLM::RateLimitError
    record_generation_timings(timings, chat, gen_started, first_token_at, tool_rounds)
    raise if flushed_upto.zero?

    raise StreamAlreadyStartedError
  end

  def record_generation_timings(timings, chat, gen_started, first_token_at, tool_rounds)
    timings["generation_ms"] = Support::ChatPipelineTiming.elapsed_ms(gen_started)
    timings["ttft_ms"] = Support::ChatPipelineTiming.elapsed_ms(gen_started, ended: first_token_at) if first_token_at
    timings["tool_rounds"] = tool_rounds
    record_token_usage(timings, chat)
  end

  def record_token_usage(timings, chat)
    return unless chat.respond_to?(:messages)

    assistant = Array(chat.messages).reverse.find { |message| message.respond_to?(:role) && message.role.to_s == "assistant" }
    return if assistant.nil?

    timings["input_tokens"] = assistant.input_tokens if assistant.respond_to?(:input_tokens) && assistant.input_tokens
    timings["output_tokens"] = assistant.output_tokens if assistant.respond_to?(:output_tokens) && assistant.output_tokens
  end

  def flush_delta!(reply, buffer, flushed_upto)
    delta = buffer[flushed_upto..]
    return if delta.blank?

    reply.conversation.broadcast_delta!(reply.id, delta)
  end

  def finalize_reply(reply, body:, error: nil, timings: {})
    persist_started = Support::ChatPipelineTiming.monotonic
    reply.update!(
      body:   body,
      status: error ? "failed" : "completed",
      error:  error
    )
    timings["persist_ms"] = Support::ChatPipelineTiming.elapsed_ms(persist_started) if timings

    broadcast_started = Support::ChatPipelineTiming.monotonic
    reply.conversation.broadcast_message!(reply)
    timings["broadcast_ms"] = Support::ChatPipelineTiming.elapsed_ms(broadcast_started) if timings

    Support::ChatPipelineTiming.persist(reply, timings) if timings.present?
  end

  def resolve_attachment_paths(message)
    return [] unless message.attachments.attached?

    message.attachments.filter_map { |att| local_path_for(att) }
  end

  def local_path_for(attachment)
    service = ActiveStorage::Blob.service
    if service.respond_to?(:path_for)
      path = service.path_for(attachment.key)
      return path if File.exist?(path)
    end

    ext = File.extname(attachment.filename.to_s)
    tempfile = Tempfile.new(["chat-att", ext], binmode: true)
    attachment.download { |chunk| tempfile.write(chunk) }
    tempfile.flush
    tempfile.path
  end
end
