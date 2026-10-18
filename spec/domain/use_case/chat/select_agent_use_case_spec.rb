# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Chat::SelectAgentUseCase do
  subject(:use_case) { described_class.new }

  describe "#call" do
    it "uses the default agent without classifying intent" do
      result = use_case.call(text: "gastei 50 no mercado")

      expect(result.agent).to eq(Llm::Agents::Registry::DEFAULT)
      expect(result.intent).to eq("unknown")
      expect(result.confidence).to eq(0.0)
    end

    it "still uses the default agent when the body is blank" do
      result = use_case.call(text: nil)

      expect(result.agent).to eq(Llm::Agents::Registry::DEFAULT)
    end

    it "honors a forced agent on the conversation" do
      result = use_case.call(text: "oi", forced_agent: :analyst)

      expect(result.agent).to eq(Llm::Agents::Registry::ANALYST)
      expect(result.intent).to be_nil
    end

    it "falls back to default when the forced agent is unknown" do
      result = use_case.call(text: "oi", forced_agent: "nope")

      expect(result.agent).to eq(Llm::Agents::Registry::DEFAULT)
    end
  end
end
