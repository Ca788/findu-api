# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::ProcessMessageJob, type: :job do
  let(:user) { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:message) do
    create(
      :chat_message,
      conversation: conversation,
      user:         user,
      payload:      { "timings" => { "enqueued_at" => 1.second.ago.iso8601(3) } }
    )
  end
  let(:use_case) { instance_double(UseCase::Chat::ProcessMessageUseCase, call: true) }

  before do
    allow(UseCase::Chat::ProcessMessageUseCase).to receive(:new).and_return(use_case)
  end

  it "records queue wait and total job duration" do
    described_class.perform_now(message)

    timings = message.reload.payload.fetch("timings")
    expect(timings["queue_wait_ms"]).to be_a(Integer)
    expect(timings["total_job_ms"]).to be_a(Integer)
    expect(use_case).to have_received(:call).with(hash_including(message: message))
  end
end
