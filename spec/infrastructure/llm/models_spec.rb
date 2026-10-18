# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::Models do
  around do |example|
    original = ENV.to_hash.slice("CHAT_AGENT_MODEL", "GEMINI_MODEL", "GEMINI_MODEL_CHAIN")
    %w[CHAT_AGENT_MODEL GEMINI_MODEL GEMINI_MODEL_CHAIN].each { |key| ENV.delete(key) }
    example.run
    %w[CHAT_AGENT_MODEL GEMINI_MODEL GEMINI_MODEL_CHAIN].each { |key| ENV.delete(key) }
    original.each { |key, value| ENV[key] = value }
  end

  describe ".chain" do
    it "resolves to a single model" do
      expect(described_class.chain("CHAT_AGENT_MODEL")).to eq([described_class::CURRENT])
    end

    it "uses the model configured for the specific call" do
      ENV["CHAT_AGENT_MODEL"] = "gemini-4.0-flash"

      expect(described_class.chain("CHAT_AGENT_MODEL")).to eq(["gemini-4.0-flash"])
    end

    it "falls back to the global model when the specific key is unset" do
      ENV["GEMINI_MODEL"] = "gemini-4.0-flash"

      expect(described_class.chain("CHAT_INTENT_MODEL")).to eq(["gemini-4.0-flash"])
    end

    it "keeps only the first id when the env var still holds a legacy CSV chain" do
      ENV["GEMINI_MODEL_CHAIN"] = "gemini-4.0-flash, gemini-3.1-flash-lite"

      expect(described_class.chain("CHAT_AGENT_MODEL")).to eq(["gemini-4.0-flash"])
    end
  end

  describe ".prefer" do
    it "ignores the model saved on the conversation" do
      expect(described_class.prefer("gemini-3.1-flash-lite")).to eq([described_class::CURRENT])
    end
  end

  describe ".available" do
    it "exposes the single current model with a label" do
      expect(described_class.available).to eq(
        [{ id: described_class::CURRENT, name: "Gemini 3.8 Flash" }]
      )
    end
  end

  describe ".known" do
    it "still accepts model ids persisted by older conversations" do
      expect(described_class.known).to include("gemini-3.1-flash-lite", described_class::CURRENT)
    end
  end
end
