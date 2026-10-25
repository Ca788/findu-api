# frozen_string_literal: true

FactoryBot.define do
  factory :device_token do
    user
    sequence(:token) { |n| "fcm-token-#{n}" }
    platform { "android" }
    last_seen_at { Time.current }
  end
end
