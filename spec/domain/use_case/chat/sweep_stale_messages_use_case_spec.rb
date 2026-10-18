# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::SweepStaleMessagesUseCase do
  subject(:use_case) { described_class.new }

  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }

  def message_with(status:, role: "assistant", body: "", updated_at: 1.hour.ago, deleted_at: nil)
    message = create(:chat_message, conversation: conversation, user: user, role: role, status: status, body: body)
    message.update_columns(updated_at: updated_at, deleted_at: deleted_at)
    message
  end

  describe "#call" do
    it "fails messages stuck in processing beyond the threshold" do
      message = message_with(status: "processing")

      expect(use_case.call).to eq(1)
      expect(message.reload).to be_failed
      expect(message.error["class"]).to eq("Chat::StaleMessage")
    end

    it "gives the assistant reply a readable body when the stream produced nothing" do
      message = message_with(status: "processing")

      use_case.call

      expect(message.reload.body).to eq(UseCase::Chat::AnswerConversationallyUseCase::FALLBACK_BODY)
    end

    it "keeps the partial text already streamed to the user" do
      message = message_with(status: "processing", body: "Sua despesa de R$")

      use_case.call

      expect(message.reload.body).to eq("Sua despesa de R$")
    end

    it "does not touch the body of a user message" do
      message = message_with(status: "processing", role: "user", body: "gastei 50 no mercado")

      use_case.call

      expect(message.reload).to have_attributes(status: "failed", body: "gastei 50 no mercado")
    end

    it "leaves a message that is still within the threshold alone" do
      message = message_with(status: "processing", updated_at: 1.minute.ago)

      expect(use_case.call).to eq(0)
      expect(message.reload).to be_processing
    end

    it "ignores messages already in a final state" do
      completed = message_with(status: "completed", body: "pronto")
      pending   = message_with(status: "pending")

      expect(use_case.call).to eq(0)
      expect(completed.reload).to be_completed
      expect(pending.reload).to be_pending
    end

    it "ignores soft deleted messages" do
      message = message_with(status: "processing", deleted_at: 1.hour.ago)

      expect(use_case.call).to eq(0)
      expect(message.reload).to be_processing
    end

    it "broadcasts the released message so the client stops waiting" do
      message = message_with(status: "processing")

      expect_any_instance_of(Chat::Conversation).to receive(:broadcast_message!).once

      use_case.call
      expect(message.reload).to be_failed
    end

    it "does not release the same message twice when two sweeps run together" do
      message_with(status: "processing")

      expect(use_case.call).to eq(1)
      expect(described_class.new.call).to eq(0)
    end

    it "respects a custom threshold" do
      message = message_with(status: "processing", updated_at: 20.minutes.ago)

      expect(use_case.call(stale_after: 1.hour)).to eq(0)
      expect(message.reload).to be_processing
    end
  end
end
