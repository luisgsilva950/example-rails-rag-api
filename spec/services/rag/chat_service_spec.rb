# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::ChatService, type: :service do
  let(:llm) { instance_double(Langchain::LLM::GoogleGemini) }
  let(:service) { described_class.new(llm: llm) }

  let(:session_id) { SecureRandom.uuid }
  let(:question) { "What is Ruby on Rails?" }
  let(:fake_embedding) { Array.new(3072) { rand(-1.0..1.0) } }

  let(:embed_response) do
    instance_double("Langchain::LLM::GoogleGeminiResponse", embedding: fake_embedding)
  end

  let(:llm_response) do
    instance_double("Langchain::LLM::GoogleGeminiResponse", chat_completion: "Rails is a web framework built with Ruby.")
  end

  let!(:doc1) { create(:document, content: "Ruby on Rails is a web framework written in Ruby.", embedding: fake_embedding) }
  let!(:doc2) { create(:document, content: "Rails follows the MVC pattern.", embedding: fake_embedding) }

  before do
    allow(llm).to receive(:embed).and_return(embed_response)
    allow(llm).to receive(:chat).and_return(llm_response)
  end

  describe "#call" do
    it "saves the user message" do
      expect {
        service.call(session_id: session_id, question: question)
      }.to change(Message, :count).by(2)
    end

    it "returns the assistant answer" do
      result = service.call(session_id: session_id, question: question)

      expect(result[:answer]).to eq("Rails is a web framework built with Ruby.")
      expect(result[:session_id]).to eq(session_id)
      expect(result[:sources_count]).to eq(2)
    end

    it "persists both user and assistant messages" do
      service.call(session_id: session_id, question: question)

      messages = Message.for_session(session_id)
      expect(messages.size).to eq(2)
      expect(messages.first.role).to eq("user")
      expect(messages.first.content).to eq(question)
      expect(messages.last.role).to eq("assistant")
      expect(messages.last.content).to eq("Rails is a web framework built with Ruby.")
    end

    it "retrieves context from PostgreSQL via pgvector" do
      service.call(session_id: session_id, question: question)

      expect(llm).to have_received(:embed).with(text: question)
    end

    it "includes context and correct roles in LLM request" do
      service.call(session_id: session_id, question: question)

      expect(llm).to have_received(:chat) do |args|
        expect(args[:system]).to include("[1]")
        expect(args[:system]).to include("Ruby on Rails is a web framework")
        roles = args[:messages].map { |m| m[:role] }
        expect(roles).to all(be_in(%w[user model]))
      end
    end

    context "with existing conversation history" do
      before do
        create(:message, :user, session_id: session_id, content: "Hello")
        create(:message, :assistant, session_id: session_id, content: "Hi! How can I help?")
      end

      it "maps roles correctly and includes history" do
        service.call(session_id: session_id, question: question)

        expect(llm).to have_received(:chat) do |args|
          messages = args[:messages]
          expect(messages.size).to be >= 3
          model_messages = messages.select { |m| m[:role] == "model" }
          expect(model_messages).not_to be_empty
        end
      end
    end

    context "when pgvector search fails" do
      before do
        allow(llm).to receive(:embed).and_raise(StandardError, "Connection refused")
      end

      it "still generates a response with fallback context" do
        result = service.call(session_id: session_id, question: question)

        expect(result[:answer]).to be_present
        expect(result[:sources_count]).to eq(0)
        expect(llm).to have_received(:chat) do |args|
          expect(args[:system]).to include("No relevant context found.")
        end
      end
    end

    context "with custom k parameter" do
      it "limits the number of results" do
        result = service.call(session_id: session_id, question: question, k: 1)

        expect(result[:sources_count]).to be <= 1
      end
    end
  end
end
