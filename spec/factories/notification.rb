# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user
    kind  { "entry_due_today" }
    title { "Aluguel vence hoje: R$ 1.800,00" }
    body  { "Moradia · vencimento 10/10" }
    data  { { "route" => "/statements/detail", "month" => "2026-10" } }
    channels { %w[in_app] }

    trait :read do
      read_at { Time.current }
    end
  end
end
