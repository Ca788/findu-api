# frozen_string_literal: true

FactoryBot.define do
  factory :financial_box, class: "Financial::Box" do
    user
    name             { "Reserva de emergência" }
    kind             { "emergency" }
    illustration_key { "shield" }
    color            { "#2F6BFF" }
    target_amount    { 10_000 }
  end
end
