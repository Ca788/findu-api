# frozen_string_literal: true

module Support
  module Money
    def self.brl(amount)
      ActiveSupport::NumberHelper.number_to_currency(
        amount.to_d,
        unit:      "R$ ",
        separator: ",",
        delimiter: ".",
        precision: 2
      )
    end
  end
end
