# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Replies::ActionBuilder do
  let(:user)         { create(:user) }
  let(:conversation) { create(:chat_conversation, user: user) }
  let(:user_message) { create(:chat_message, conversation: conversation, user: user, role: "user") }

  describe ".call" do
    it "builds a receipt card and register action when confirmation is pending" do
      user_message.update!(
        payload: {
          "receipt_awaiting_confirmation" => true,
          "receipt_candidates" => [{
            "amount" => "87.9",
            "description" => "Farmácia",
            "transaction_type" => "expense",
            "occurred_at" => "2026-10-18"
          }]
        }
      )

      result = described_class.call(user_message: user_message)

      expect(result.actions).to include(
        a_hash_including("id" => "register_expense", "label" => "Registrar despesa", "kind" => "send_message"),
        a_hash_including("id" => "dismiss_register", "variant" => "secondary")
      )
      expect(result.card["title"]).to eq("Despesa identificada")
      expect(result.card["fields"]).to include(
        a_hash_including("label" => "Valor", "value" => "R$87,90"),
        a_hash_including("label" => "Descrição", "value" => "Farmácia")
      )
    end

    it "prefers tool follow-up when a creating tool already succeeded" do
      user_message.update!(payload: { "receipt_awaiting_confirmation" => true })

      result = described_class.call(
        user_message: user_message,
        tool_results: [{
          "name"   => "register_transaction",
          "result" => {
            "success"     => true,
            "amount"      => "50.0",
            "type"        => "expense",
            "description" => "Mercado",
            "category"    => "Alimentação"
          }
        }]
      )

      expect(result.actions).to contain_exactly(
        a_hash_including("id" => "view_statement", "kind" => "navigate", "href" => "/statements")
      )
      expect(result.card["title"]).to eq("Despesa registrada")
    end

    it "returns empty actions when there is nothing structured" do
      result = described_class.call(user_message: user_message)

      expect(result.actions).to eq([])
      expect(result.card).to be_nil
    end
  end
end
