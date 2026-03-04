# frozen_string_literal: true

module Api
  module V1
    # POST /api/v1/chats — sends a question to the RAG pipeline.
    class ChatsController < BaseController
      def create
        validate_chat_params!
        result = Rag::ChatService.new.call(session_id: chat_params[:session_id], question: chat_params[:question])
        render json: result, status: :created
      end

      private

      def chat_params
        params.permit(:session_id, :question)
      end

      def validate_chat_params!
        raise ArgumentError, "session_id is required" if chat_params[:session_id].blank?
        raise ArgumentError, "question is required" if chat_params[:question].blank?
      end
    end
  end
end
