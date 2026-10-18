# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::AnswerConversationallyUseCase do
  subject(:use_case) do
    described_class.new(context_builder: context_builder, prompt_builder: prompt_builder)
  end

  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:user_message) { create(:chat_message, conversation: conversation, user: user, role: "user", body: "Oi") }

  let(:context_builder) { instance_double(UseCase::Chat::BuildUserContextUseCase, call: {}) }
  let(:prompt_builder)  { instance_double(Llm::Prompts::ChatAgentPromptBuilder, call: "system prompt") }

  let(:fake_chat) do
    instance_double(RubyLLM::Chat).tap do |chat|
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:with_tools).and_return(chat)
      allow(chat).to receive(:add_message).and_return(chat)
      allow(chat).to receive(:on_tool_call).and_return(chat)
      allow(chat).to receive(:on_tool_result).and_return(chat)
      allow(chat).to receive(:messages).and_return([])
    end
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)
  end

  # Drives the streaming block with the given text chunks.
  def stream_chunks(*chunks)
    allow(fake_chat).to receive(:ask) do |_body, **_opts, &on_chunk|
      chunks.each { |text| on_chunk.call(double(content: text)) }
    end
  end

  describe "#call" do
    it "persists the assembled body and marks the reply completed" do
      stream_chunks("Olá", ", ", "tudo bem?")

      reply = use_case.call(user_message: user_message)

      expect(reply.reload).to have_attributes(
        role:   "assistant",
        status: "completed",
        body:   "Olá, tudo bem?"
      )
      expect(reply.parent_message_id).to eq(user_message.id)
    end

    it "attaches receipt confirmation actions when the user message awaits confirmation" do
      user_message.update!(
        payload: {
          "receipt_awaiting_confirmation" => true,
          "receipt_candidates" => [{
            "amount" => "50.0",
            "description" => "Mercado",
            "transaction_type" => "expense"
          }]
        }
      )
      stream_chunks("Confere esses dados?")

      reply = use_case.call(user_message: user_message)
      payload = reply.reload.payload

      expect(payload["actions"]).to include(
        a_hash_including("id" => "register_expense", "label" => "Registrar despesa")
      )
      expect(payload["card"]).to include("title" => "Despesa identificada")
    end

    it "records generation timings on the assistant message" do
      stream_chunks("Olá", ", ", "tudo bem?")

      reply = use_case.call(user_message: user_message)
      timings = reply.reload.payload.fetch("timings")

      expect(timings["prompt_chars"]).to eq("system prompt".length)
      expect(timings["history_messages"]).to eq(0)
      expect(timings["ttft_ms"]).to be_a(Integer)
      expect(timings["generation_ms"]).to be_a(Integer)
      expect(timings["tool_rounds"]).to eq(0)
      expect(timings["persist_ms"]).to be_a(Integer)
      expect(timings["broadcast_ms"]).to be_a(Integer)
      expect(timings["context_ms"]).to be_a(Integer)
    end

    it "falls back when the model yields no content" do
      stream_chunks("")

      reply = use_case.call(user_message: user_message)

      expect(reply.reload.body).to eq(described_class::FALLBACK_BODY)
    end

    context "when the model hits a rate limit" do
      before { allow(fake_chat).to receive(:ask).and_raise(RubyLLM::RateLimitError.new("rate")) }

      it "finalizes with the rate-limit message and keeps the reply completed" do
        reply = use_case.call(user_message: user_message)

        expect(reply.reload).to have_attributes(
          status: "completed",
          body:   described_class::RATE_LIMIT_BODY
        )
      end
    end

    context "when the model raises an unexpected error" do
      before { allow(fake_chat).to receive(:ask).and_raise(StandardError, "boom") }

      it "finalizes with the fallback body and marks the reply failed" do
        reply = use_case.call(user_message: user_message)

        expect(reply.reload).to have_attributes(status: "failed", body: described_class::FALLBACK_BODY)
        expect(reply.error["message"]).to eq("boom")
      end
    end
  end

  describe "delta broadcasting" do
    let(:reply) do
      conversation.messages.create!(user: user, role: "assistant", kind: "text", status: "processing", body: "")
        .tap { |message| allow(message).to receive(:conversation).and_return(conversation) }
    end

    it "broadcasts only the text produced since the previous flush" do
      allow(conversation).to receive(:broadcast_delta!)

      use_case.send(:flush_delta!, reply, "Olá, tudo bem?", 3)

      expect(conversation).to have_received(:broadcast_delta!).with(reply.id, ", tudo bem?")
    end

    it "does not broadcast when there is no new text" do
      allow(conversation).to receive(:broadcast_delta!)

      use_case.send(:flush_delta!, reply, "Olá", 3)

      expect(conversation).not_to have_received(:broadcast_delta!)
    end
  end
end
