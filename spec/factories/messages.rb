# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    session_id { SecureRandom.uuid }
    role { "user" }
    content { Faker::Lorem.paragraph }

    trait :user do
      role { "user" }
    end

    trait :assistant do
      role { "assistant" }
    end

    trait :system do
      role { "system" }
    end
  end
end
