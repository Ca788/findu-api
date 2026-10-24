# frozen_string_literal: true

module Llm
  module Schemas
    class ReceiptSchema < RubyLLM::Schema
      number :amount,             description: "TOTAL paid, decimal with DOT (13.94). Brazilian 'R$ 13,94' is 13.94. Use the line labeled Total. Never 0 if a price is visible; use null if unknown."
      string :occurred_at,        description: "Transaction date in ISO 8601 format (YYYY-MM-DD or full timestamp). Null if not visible."
      string :description,        description: "Vendor or merchant name plus a short description (e.g. 'Posto Shell - combustivel')"
      string :raw_text,           description: "Full raw text extracted from the receipt/screenshot"
      number :confidence,         description: "Self-reported confidence between 0.0 and 1.0"
      string :transaction_type,   description: "'expense' for purchases and payments, 'income' for refunds, cashbacks or received payments. Default 'expense' when unclear."
      boolean :is_installment,    description: "True when the document shows a purchase in installments (e.g. '3x', '12 parcelas', 'parcela 2/10')."
      number :total_installments, description: "Number of installments when is_installment is true. Null otherwise."
      number :monthly_amount,     description: "Amount of each installment when visible. Null if not installment or not visible."
      number :total_amount,       description: "Total financed amount when installment. Prefer this over amount when both are visible."
    end
  end
end
