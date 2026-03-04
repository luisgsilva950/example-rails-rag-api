# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/ingestions — enqueues a document ingestion as a background job.
    # GET  /api/v1/ingestions/:id — returns the current ingestion status.
    class IngestionsController < BaseController
      ACCEPTED_CONTENT_TYPES = %w[
        application/pdf
        text/plain
        application/json
        text/markdown
      ].freeze

      def create
        validate_file_param!
        temp_path = save_temp_file(params[:file])
        ingestion = Ingestion.create!(filename: params[:file].original_filename, file_path: temp_path)
        Rag::IngestionJob.perform_later(ingestion.id)
        render json: accepted_response(ingestion), status: :accepted
      end

      def show
        ingestion = Ingestion.find(params[:id])
        render json: status_response(ingestion)
      end

      private

      def validate_file_param!
        raise ArgumentError, "File parameter is required" unless params[:file].present?
        raise ArgumentError, "Invalid file upload" unless params[:file].respond_to?(:original_filename)
        raise ArgumentError, "Unsupported file type. Accepted: PDF, TXT, JSON, MD" unless accepted_content_type?
      end

      def accepted_content_type?
        ACCEPTED_CONTENT_TYPES.include?(params[:file].content_type)
      end

      def save_temp_file(uploaded_file)
        temp_dir = Rails.root.join("tmp", "uploads")
        FileUtils.mkdir_p(temp_dir)
        temp_path = temp_dir.join(uploaded_file.original_filename).to_s
        File.open(temp_path, "wb") { |f| f.write(uploaded_file.read) }
        temp_path
      end

      def accepted_response(ingestion)
        { message: "Document queued for ingestion",
          ingestion_id: ingestion.id,
          status: ingestion.status,
          filename: ingestion.filename }
      end

      def status_response(ingestion)
        { id: ingestion.id,
          status: ingestion.status,
          filename: ingestion.filename,
          chunks_count: ingestion.chunks_count,
          error_message: ingestion.error_message }
      end
    end
  end
end
