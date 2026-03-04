# frozen_string_literal: true

module Rag
  # Tool that allows the LLM to search for relevant documents
  # via pgvector similarity search. Used by Langchain::Assistant
  # for function calling with Gemini.
  class DocumentSearchTool
    extend Langchain::ToolDefinition

    define_function :search, description: "Search for relevant documents using semantic similarity" do
      property :query, type: "string", description: "The search query to find relevant documents", required: true
      property :limit, type: "integer", description: "Maximum number of documents to return (default: 4)"
    end

    def initialize(llm: GEMINI_LLM)
      @llm = llm
    end

    def search(query:, limit: 4)
      embedding = @llm.embed(text: query).embedding
      documents = Document.search(embedding, limit: limit)
      format_results(documents)
    end

    private

    def format_results(documents)
      return "No relevant documents found." if documents.blank?

      documents.map.with_index(1) { |doc, i| "[#{i}] #{doc.content}" }.join("\n\n")
    end
  end
end
