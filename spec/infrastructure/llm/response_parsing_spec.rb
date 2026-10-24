# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::ResponseParsing do
  subject(:parser) { Object.new.extend(described_class) }

  describe "#parse_decimal" do
    it "parses US dotted decimals" do
      expect(parser.parse_decimal("13.94")).to eq(BigDecimal("13.94"))
    end

    it "parses Brazilian comma decimals and currency" do
      expect(parser.parse_decimal("13,94")).to eq(BigDecimal("13.94"))
      expect(parser.parse_decimal("R$ 13,94")).to eq(BigDecimal("13.94"))
      expect(parser.parse_decimal("1.234,56")).to eq(BigDecimal("1234.56"))
    end

    it "parses numeric values" do
      expect(parser.parse_decimal(13.94)).to eq(BigDecimal("13.94"))
    end

    it "returns nil for blank" do
      expect(parser.parse_decimal(nil)).to be_nil
      expect(parser.parse_decimal("")).to be_nil
    end
  end

  describe "#largest_money_in" do
    it "picks the Total on an Uber-like receipt, ignoring 0,00" do
      text = "Uber\nTotal  R$ 0,00\nTotal  R$ 13,94"
      expect(parser.largest_money_in(text)).to eq(BigDecimal("13.94"))
    end

    it "returns nil when there is no money" do
      expect(parser.largest_money_in("sem valores")).to be_nil
    end
  end
end
