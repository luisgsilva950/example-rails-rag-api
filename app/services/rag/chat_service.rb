# frozen_string_literal: true

module Rag
  # Orchestrates RAG chat: retrieves context via pgvector,
  # sends augmented prompt to Gemini, and persists messages.
  class ChatService
    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful assistant. Use the provided context to answer the user's question.
      If the context does not contain relevant information, say so honestly.
      Always be concise and accurate.
    PROMPT

    GEMINI_ROLES = { "assistant" => "model", "system" => "user" }.freeze

    attr_reader :llm

    def initialize(llm: GEMINI_LLM)
      @llm = llm
    end

    def call(session_id:, question:, k: 4)
      save_message(session_id: session_id, role: "user", content: question)
      context = retrieve_context(question, k: k)
      answer = ask_llm(session_id: session_id, context: context)
      save_message(session_id: session_id, role: "assistant", content: answer)
      { session_id: session_id, answer: answer, sources_count: context.size }
    end

    private

    def retrieve_context(query, k:)
      embedding = llm.embed(text: query).embedding
      Document.search(embedding, limit: k)
    rescue StandardError => e
      Rails.logger.warn("pgvector search failed: #{e.message}")
      []
    end

    def ask_llm(session_id:, context:)
      messages = build_messages(session_id: session_id)
      system_instruction = "#{SYSTEM_PROMPT}\n\nContext:\n#{format_context(context)}"
      llm.chat(messages: messages, system: system_instruction).chat_completion
    end

    def build_messages(session_id:)
      Message.for_session(session_id).last(10).map do |msg|
        { role: GEMINI_ROLES.fetch(msg.role, "user"), parts: [ { text: msg.content } ] }
      end
    end

    def format_context(context)
      return "No relevant context found." if context.blank?

      context.map.with_index(1) { |doc, i| "[#{i}] #{doc.content}" }.join("\n\n")
    end

    def save_message(session_id:, role:, content:)
      Message.create!(session_id: session_id, role: role, content: content)
    end
  end
end
