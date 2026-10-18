# frozen_string_literal: true

require "rails_helper"

RSpec.describe Support::ChatPipelineTiming do
  describe ".measure" do
    it "returns the block result and a non-negative duration" do
      result, elapsed = described_class.measure("test") { :ok }

      expect(result).to eq(:ok)
      expect(elapsed).to be_a(Integer)
      expect(elapsed).to be >= 0
    end

    it "emits an ActiveSupport notification with duration_ms" do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("chat.pipeline.test") do |*_args, payload|
        events << payload
      end

      described_class.measure("test", message_id: "abc") { true }

      expect(events.last["duration_ms"]).to be_a(Integer)
      expect(events.last["message_id"]).to eq("abc")
      expect(events.last["error"]).to eq(false)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it "re-raises after notifying on error" do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("chat.pipeline.test") do |*_args, payload|
        events << payload
      end

      expect {
        described_class.measure("test") { raise ArgumentError, "boom" }
      }.to raise_error(ArgumentError, "boom")

      expect(events.last["error"]).to eq(true)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  describe ".queue_wait_ms" do
    it "returns nil for a blank timestamp" do
      expect(described_class.queue_wait_ms(nil)).to be_nil
    end

    it "returns a non-negative wait from an ISO-8601 timestamp" do
      wait = described_class.queue_wait_ms(2.seconds.ago.iso8601(3))

      expect(wait).to be >= 0
    end
  end

  describe ".persist" do
    let(:user) { create(:user) }
    let(:conversation) { create(:chat_conversation, user: user) }
    let(:message) { create(:chat_message, conversation: conversation, user: user, payload: { "foo" => "bar" }) }

    it "merges timings without dropping existing payload keys" do
      described_class.persist(message, "intent_ms" => 12)

      payload = message.reload.payload
      expect(payload["foo"]).to eq("bar")
      expect(payload["timings"]["intent_ms"]).to eq(12)
    end
  end
end
