# frozen_string_literal: true

module Rag
  # Processes a file ingestion in the background.
  # Delegates text extraction and embedding to IngestionService.
  class IngestionJob < ApplicationJob
    queue_as :default

    def perform(ingestion_id)
      ingestion = Ingestion.find(ingestion_id)
      return unless ingestion.pending?

      ingestion.mark_processing!
      result = Rag::IngestionService.new.call(file_path: ingestion.file_path)
      ingestion.mark_completed!(chunks_count: result[:chunks_count])
    rescue StandardError => e
      ingestion&.mark_failed!(error_message: e.message)
      Rails.logger.error("IngestionJob failed for Ingestion##{ingestion_id}: #{e.message}")
    end
  end
end
