# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::Prompts::ReceiptPromptBuilder do
  it "tells the model to read Brazilian Total lines and never return 0" do
    prompt = described_class.new.call(today: Date.new(2026, 10, 18))

    expect(prompt).to include("R$ 13,94")
    expect(prompt).to include("NEVER return 0")
    expect(prompt).to include("Uber")
  end
end
