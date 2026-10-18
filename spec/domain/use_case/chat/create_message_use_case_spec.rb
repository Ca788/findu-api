# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::CreateMessageUseCase do
  subject(:use_case) { described_class.new }

  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }

  describe "#call" do
    context "with a text body" do
      it "creates a user message in pending status" do
        message = use_case.call(conversation: conversation, user: user, body: "gastei 50 no mercado")

        expect(message).to be_persisted
        expect(message).to have_attributes(
          role:   "user",
          kind:   "text",
          status: "pending",
          body:   "gastei 50 no mercado",
          user_id: user.id,
          conversation_id: conversation.id
        )
      end

      it "enqueues Chat::ProcessMessageJob" do
        expect {
          use_case.call(conversation: conversation, user: user, body: "gastei 50")
        }.to have_enqueued_job(Chat::ProcessMessageJob)
      end

      it "stamps enqueue timing on the message payload" do
        message = use_case.call(conversation: conversation, user: user, body: "gastei 50")
        timings = message.reload.payload.fetch("timings")

        expect(timings["enqueued_at"]).to be_present
        expect(timings["create_ms"]).to be_a(Integer)
      end
    end

    context "when body, audio and attachments are all blank" do
      it "raises ArgumentError" do
        expect {
          use_case.call(conversation: conversation, user: user, body: nil, audio: nil, attachments: [])
        }.to raise_error(ArgumentError, /body, audio or attachments/)
      end
    end
  end
end
