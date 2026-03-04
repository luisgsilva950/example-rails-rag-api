# frozen_string_literal: true

class Document < ApplicationRecord
  has_neighbors :embedding

  validates :content, presence: true

  scope :search, ->(embedding, limit: 4) {
    nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
  }
end
