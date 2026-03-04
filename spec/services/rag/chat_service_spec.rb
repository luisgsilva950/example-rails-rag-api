# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::ChatService, type: :service do
  let(:llm) { instance_double(Langchain::LLM::GoogleGemini) }
  let(:tool) { instance_double(Rag::DocumentSearchTool) }
  let(:assistant) { instance_double(Langchain::Assistant) }
  let(:service) { described_class.new(llm: llm, tools: [ tool ]) }

  let(:session_id) { SecureRandom.uuid }
  let(:question) { "What is Ruby on Rails?" }

  let(:final_message) do
    instance_double(
      "Langchain::Assistant::Messages::GoogleGeminiMessage",
      content: "Rails is a web framework built with Ruby."
    )
  end

  before do
    allow(Langchain::Assistant).to receive(:new).and_return(assistant)
    allow(assistant).to receive(:add_message)
    allow(assistant).to receive(:add_message_and_run!)
    allow(assistant).to receive(:messages).and_return([ final_message ])
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

    it "creates assistant with tools and instructions" do
      service.call(session_id: session_id, question: question)

      expect(Langchain::Assistant).to have_received(:new).with(
        llm: llm,
        tools: [ tool ],
        instructions: described_class::SYSTEM_PROMPT
      )
    end

    it "sends the question to the assistant" do
      service.call(session_id: session_id, question: question)

      expect(assistant).to have_received(:add_message_and_run!).with(content: question)
    end

    context "with existing conversation history" do
      before do
        create(:message, :user, session_id: session_id, content: "Hello")
        create(:message, :assistant, session_id: session_id, content: "Hi! How can I help?")
      end

      it "loads history with correct Gemini roles" do
        service.call(session_id: session_id, question: question)

        expect(assistant).to have_received(:add_message).with(role: "user", content: "Hello")
        expect(assistant).to have_received(:add_message).with(role: "model", content: "Hi! How can I help?")
        expect(assistant).to have_received(:add_message).with(role: "user", content: question)
      end
    end
  end
end
