# frozen_string_literal: true

class Message < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  validates :session_id, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :for_session, ->(session_id) { where(session_id: session_id).order(:created_at) }
end
