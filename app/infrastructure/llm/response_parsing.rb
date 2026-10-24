# frozen_string_literal: true

module Llm
  module ResponseParsing
    DEFAULT_FALLBACK_PAYLOAD = { "confidence" => 0.0 }.freeze

    # @param [String]
    # @param [Class]
    # @param [Array<String>]
    # @param [#call]
    # @param [Hash]
    # @return [Hash]
    def llm_extract(text:, schema:, models:, prompt_builder:, fallback: DEFAULT_FALLBACK_PAYLOAD)
      response = Llm::ModelFallback.with_fallback(models) do |model|
        Llm::GeminiChat.for(model).with_schema(schema).ask(prompt_builder.call(text: text))
      end
      parse_payload(response.content, fallback: fallback)
    end

    # @param [Object]
    # @param [Hash]
    # @return [Hash]
    def parse_payload(content, fallback: DEFAULT_FALLBACK_PAYLOAD)
      return content if content.is_a?(Hash)

      JSON.parse(content.to_s)
    rescue JSON::ParserError
      fallback
    end

    MONEY_IN_TEXT = /
      (?:r\$\s*)?
      (
        \d{1,3}(?:\.\d{3})+,\d{2}
        |\d+,\d{2}
        |\d+\.\d{2}
      )
    /ix

    # Aceita 13.94, "13,94", "R$ 13,94" e "1.234,56".
    # @param [Object]
    # @return [BigDecimal, nil]
    def parse_decimal(value)
      return nil if value.nil?

      if value.is_a?(Numeric)
        BigDecimal(value.to_s)
      else
        parse_decimal_string(value.to_s)
      end
    rescue ArgumentError
      nil
    end

    # @param [String]
    # @return [BigDecimal, nil]
    def largest_money_in(text)
      return nil if text.blank?

      values = text.to_s.scan(MONEY_IN_TEXT).flatten.filter_map do |token|
        amount = parse_decimal(token)
        amount if amount&.positive?
      end
      values.max
    end

    # @param [Object]
    # @return [String]
    def parse_transaction_type(value)
      return "expense" unless value.to_s.in?(%w[expense income])

      value.to_s
    end

    # @param [Object]
    # @return [Time, nil]
    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    # @param [Object]
    # @return [Date, nil]
    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError, TypeError
      nil
    end

    def parse_decimal_string(raw)
      cleaned = raw.strip
      return nil if cleaned.blank?

      cleaned = cleaned.sub(/\A(?:r\$|rs)\s*/i, "")
      cleaned = if cleaned.match?(/\d+\.\d{3},\d{2}\z/)
        cleaned.gsub(".", "").sub(",", ".")
      elsif cleaned.include?(",")
        cleaned.tr(",", ".")
      else
        cleaned
      end
      cleaned = cleaned.gsub(/[^\d.\-]/, "")
      return nil if cleaned.blank?

      BigDecimal(cleaned)
    end
    private :parse_decimal_string
  end
end
