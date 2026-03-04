# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    content { Faker::Lorem.paragraph }
    source { "sample.pdf" }
    embedding { Array.new(3072) { rand(-1.0..1.0) } }
  end
end
