# frozen_string_literal: true

module Rag
  # Orchestrates RAG chat with Tool Use: the LLM decides when to
  # search for documents via function calling, enabling dynamic
  # context retrieval instead of always-on retrieval.
  class ChatService
    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful assistant with access to tools.
      Use the available tools to find relevant information before answering questions.
      If the tools return no relevant results, say so honestly.
      Always be concise and accurate.

      Make the text beautiful and easy to read. Use markdown formatting where appropriate.
    PROMPT

    GEMINI_ROLES = { "assistant" => "model" }.freeze

    attr_reader :assistant

    def initialize(llm: GEMINI_LLM, tools: self.class.default_tools)
      @assistant = Langchain::Assistant.new(
        llm: llm,
        tools: tools,
        instructions: SYSTEM_PROMPT
      )
    end

    def call(session_id:, question:)
      save_message(session_id: session_id, role: "user", content: question)
      load_history(session_id: session_id)
      answer = run_assistant(question)
      save_message(session_id: session_id, role: "assistant", content: answer)
      { session_id: session_id, answer: answer }
    end

    private

    def load_history(session_id:)
      Message.for_session(session_id).last(10).each do |msg|
        role = GEMINI_ROLES.fetch(msg.role, msg.role)
        assistant.add_message(role: role, content: msg.content)
      end
    end

    def run_assistant(question)
      assistant.add_message_and_run!(content: question)
      assistant.messages.last.content
    end

    def save_message(session_id:, role:, content:)
      Message.create!(session_id: session_id, role: role, content: content)
    end

    def self.default_tools
      [ DocumentSearchTool.new, StyrofoamEarthquakeTool.new ]
    end
  end
end
