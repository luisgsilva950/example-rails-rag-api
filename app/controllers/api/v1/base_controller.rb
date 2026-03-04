# frozen_string_literal: true

module Api
  module V1
    # Base controller for API V1 — handles error responses.
    class BaseController < ApplicationController
      rescue_from StandardError, with: :handle_internal_error
      rescue_from ArgumentError, with: :handle_bad_request
      rescue_from ActiveRecord::RecordInvalid, with: :handle_unprocessable_entity

      private

      def handle_internal_error(exception)
        Rails.logger.error("Internal error: #{exception.message}")
        render_error("Internal server error", exception.message, :internal_server_error)
      end

      def handle_bad_request(exception)
        render_error("Bad request", exception.message, :bad_request)
      end

      def handle_unprocessable_entity(exception)
        render_error("Unprocessable entity", exception.message, :unprocessable_entity)
      end

      def render_error(error_label, message, status)
        render json: { error: error_label, message: parse_message(message) }, status: status
      end

      def parse_message(message)
        try_parse_json(message) || try_parse_json(message.gsub(/=>/, ":")) || message
      end

      def try_parse_json(string)
        JSON.parse(string)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
