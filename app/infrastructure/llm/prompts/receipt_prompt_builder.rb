# frozen_string_literal: true

module Llm
  module Prompts
    class ReceiptPromptBuilder
      # @param [Date]
      # @return [String]
      def call(today: Date.current)
        <<~PROMPT
          You are an OCR engine for personal finance receipts and payment screenshots.
          Today's date is #{today.iso8601} (use it as reference when inferring missing parts of dates).
          Extract the data into the provided JSON schema.
          Rules:
            - amount: numeric TOTAL PAID (no currency symbol, DOT as decimal separator).
                * Brazilian receipts use comma: "R$ 13,94" → 13.94. "1.234,56" → 1234.56.
                * Prefer the line labeled Total, Valor total, Total da viagem, Total do pedido.
                * On Uber / 99 / inDrive / iFood screenshots the amount is the large Total at the bottom.
                * NEVER return 0 when any R$ value is visible. 0 means "not found" — use null instead.
            - occurred_at: date the transaction happened, ISO 8601 (YYYY-MM-DD or full timestamp).
                * If the document shows only day and month (e.g. "Apr 22", "9 de set."), assume the year is #{today.year},
                  unless that would put the date in the future relative to today; in that case, use #{today.year - 1}.
                * Never invent a year that contradicts the receipt.
            - description: vendor / merchant + short context (e.g. "Uber", "iFood").
            - raw_text: copy as much text as possible from the document, including every R$ value.
            - confidence: how sure you are about the extracted data (0.0 to 1.0).
            - transaction_type: 'expense' for money spent; 'income' for refunds, cashbacks or received payments. Default 'expense'.
            - is_installment: true if you see installments (Nx, parcela X/Y, parcelado, etc.).
            - total_installments: integer N when installment.
            - monthly_amount: value of each installment when shown.
            - total_amount: full purchase total when installment (prefer over amount when both exist). For a simple receipt, copy amount.
          If a field cannot be determined, return null for that field (except raw_text, confidence, transaction_type and is_installment).
        PROMPT
      end
    end
  end
end
