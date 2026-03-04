# frozen_string_literal: true

FactoryBot.define do
  factory :ingestion do
    status { "pending" }
    filename { "sample.pdf" }
    file_path { Rails.root.join("tmp", "uploads", "sample.pdf").to_s }
  end
end
