# frozen_string_literal: true

module Llm
  module Schemas
    class ChatIntentSchema < RubyLLM::Schema
      INTENTS = %w[
        create_transaction
        create_budget
        create_goal
        create_investment
        create_category
        create_installment
        query_balance
        query_budget
        query_goal
        query_investment
        delete_transaction
        unknown
      ].freeze

      string :intent,
             description: "The user's intent. One of: create_transaction (registering a single expense/income), create_budget (setting a spending limit for a period), create_goal (savings target with an amount to reach), create_investment (recording an investment/application), create_category (creating a new category), create_installment (parcelamento of a purchase), query_balance (asking about totals/summary), query_budget (asking how much can still be spent), query_goal (asking about savings goal progress), query_investment (asking about the investment portfolio or returns), delete_transaction (deleting one or many existing transactions, cleaning up history, removing duplicates), unknown (none of the above).",
             enum: INTENTS
      number :confidence, description: "How sure you are (0.0 to 1.0)."
    end
  end
end
