# frozen_string_literal: true

FactoryBot.define do
  factory :financial_goal, class: "Financial::Goal" do
    user
    name           { "Viagem" }
    target_amount  { 5_000 }
    current_amount { 0 }
    deadline       { 6.months.from_now.to_date }
    status         { "active" }
  end
end
