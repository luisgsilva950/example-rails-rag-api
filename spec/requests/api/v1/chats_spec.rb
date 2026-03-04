# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Chats", type: :request do
  describe "POST /api/v1/chats" do
    let(:session_id) { SecureRandom.uuid }
    let(:question) { "What is Ruby on Rails?" }
    let(:chat_result) do
      {
        session_id: session_id,
        answer: "Rails is a web application framework written in Ruby.",
        sources_count: 3
      }
    end
    let(:chat_service) { instance_double(Rag::ChatService) }

    before do
      allow(Rag::ChatService).to receive(:new).and_return(chat_service)
      allow(chat_service).to receive(:call).and_return(chat_result)
    end

    context "with valid parameters" do
      it "returns 201 with the assistant answer" do
        post "/api/v1/chats", params: { session_id: session_id, question: question }

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json["session_id"]).to eq(session_id)
        expect(json["answer"]).to eq("Rails is a web application framework written in Ruby.")
        expect(json["sources_count"]).to eq(3)
      end

      it "calls the chat service with correct parameters" do
        post "/api/v1/chats", params: { session_id: session_id, question: question }

        expect(chat_service).to have_received(:call).with(
          session_id: session_id,
          question: question
        )
      end
    end

    context "without session_id" do
      it "returns 400 bad request" do
        post "/api/v1/chats", params: { question: question }

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["message"]).to include("session_id is required")
      end
    end

    context "without question" do
      it "returns 400 bad request" do
        post "/api/v1/chats", params: { session_id: session_id }

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["message"]).to include("question is required")
      end
    end

    context "when chat service raises an error" do
      before do
        allow(chat_service).to receive(:call).and_raise(StandardError, "LLM API timeout")
      end

      it "returns 500 internal server error" do
        post "/api/v1/chats", params: { session_id: session_id, question: question }

        expect(response).to have_http_status(:internal_server_error)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Internal server error")
      end
    end

    context "with multiple messages in a session" do
      it "maintains conversation context" do
        # First message
        post "/api/v1/chats", params: { session_id: session_id, question: "Hello" }
        expect(response).to have_http_status(:created)

        # Second message (same session)
        post "/api/v1/chats", params: { session_id: session_id, question: "Tell me more" }
        expect(response).to have_http_status(:created)

        expect(chat_service).to have_received(:call).twice
      end
    end
  end
end
