# frozen_string_literal: true

class Ingestion < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :filename, presence: true
  validates :file_path, presence: true

  scope :by_status, ->(status) { where(status: status) }

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_completed!(chunks_count:)
    update!(status: "completed", chunks_count: chunks_count)
  end

  def mark_failed!(error_message:)
    update!(status: "failed", error_message: error_message)
  end
end
