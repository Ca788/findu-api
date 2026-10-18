# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Messaging::ProcessInboundMessageUseCase do
  subject(:use_case) do
    described_class.new(
      provider:                     provider,
      artifact_extractor:           artifact_extractor,
      artifact_transaction_creator: artifact_transaction_creator
    )
  end

  let(:user)     { create(:user, phone: "+5511999999999") }
  let(:provider) { instance_double(Messaging::Twilio::Provider) }

  let(:artifact_extractor) { instance_double(UseCase::Artifact::ExtractArtifactDataUseCase) }
  let(:artifact_transaction_creator) do
    instance_double(UseCase::Artifact::CreateTransactionFromArtifactUseCase)
  end

  let(:message) do
    Messaging::Message.new(
      from:     user.phone,
      reply_to: "whatsapp:#{user.phone}",
      body:     "",
      media:    [{ url: "https://api.twilio.com/media/ME1", content_type: "image/jpeg" }],
      raw:      {}
    )
  end

  before do
    allow(provider).to receive(:fetch_media).and_return(
      { io: StringIO.new("fake-image"), filename: "receipt.jpg", content_type: "image/jpeg" }
    )
    allow(Messaging::SendMessageJob).to receive(:perform_later)
  end

  describe "#call with an image" do
    let(:transaction) { create(:financial_transaction, :expense, user: user, amount: 150.75) }

    before do
      allow(artifact_extractor).to receive(:call) do |artifact:|
        artifact.tap { |record| record.update!(status: "processed") }
      end
      allow(artifact_transaction_creator).to receive(:call).and_return(transaction)
    end

    it "does not enqueue the OCR job" do
      expect(Artifacts::ProcessOcrJob).not_to receive(:perform_later)

      use_case.call(message: message)
    end

    it "creates the artifact for the sender" do
      expect { use_case.call(message: message) }.to change(user.artifacts, :count).by(1)
    end

    it "extracts and registers inline, then enqueues a single reply" do
      use_case.call(message: message)

      expect(artifact_extractor).to have_received(:call).once
      expect(artifact_transaction_creator).to have_received(:call).once
      expect(Messaging::SendMessageJob).to have_received(:perform_later).once.with(
        message.reply_to,
        Chat::Replies::Formatter.transaction(transaction)
      )
    end

    context "when the artifact needs review" do
      before do
        allow(artifact_extractor).to receive(:call) do |artifact:|
          artifact.tap { |record| record.update!(status: "needs_review") }
        end
      end

      it "replies without creating a transaction" do
        use_case.call(message: message)

        expect(artifact_transaction_creator).not_to have_received(:call)
        expect(Messaging::SendMessageJob).to have_received(:perform_later).once
      end
    end

    context "when the extraction fails" do
      before do
        allow(artifact_extractor).to receive(:call).and_raise(RuntimeError, "gemini down")
      end

      it "still enqueues a reply instead of losing the message" do
        expect { use_case.call(message: message) }.not_to raise_error

        expect(Messaging::SendMessageJob).to have_received(:perform_later).once.with(
          message.reply_to,
          /não consegui ler os dados/
        )
      end
    end

    context "when the transaction cannot be created" do
      before do
        allow(artifact_transaction_creator).to receive(:call)
          .and_raise(ArgumentError, "amount is required to create transaction")
      end

      it "still enqueues a reply instead of losing the message" do
        expect { use_case.call(message: message) }.not_to raise_error

        expect(Messaging::SendMessageJob).to have_received(:perform_later).once
      end
    end
  end

  describe "#call from an unknown phone" do
    let(:message) do
      Messaging::Message.new(from: "+5511000000000", reply_to: "whatsapp:+5511000000000", body: "oi", media: [], raw: {})
    end

    it "answers that the number is not registered" do
      expect(provider).to receive(:send_message).with(to: message.reply_to, body: /não cadastrado/)

      use_case.call(message: message)
    end
  end
end
