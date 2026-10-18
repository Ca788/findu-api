# frozen_string_literal: true

FactoryBot.define do
  factory :financial_investment, class: "Financial::Investment" do
    user
    name             { "Tesouro Selic" }
    asset_type       { "treasury" }
    institution      { "Banco" }
    invested_amount  { 1_000 }
    current_amount   { 1_100 }
    invested_on      { Date.current }
    status           { "active" }
  end
end
