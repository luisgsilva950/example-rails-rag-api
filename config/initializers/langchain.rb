# frozen_string_literal: true

# Global Langchain.rb client configuration
# These clients are initialized once and reused across the application.

GEMINI_MODEL = ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_EMBEDDING_MODEL = ENV.fetch("GEMINI_EMBEDDING_MODEL", "gemini-embedding-001")

GEMINI_LLM = Langchain::LLM::GoogleGemini.new(
  api_key: ENV.fetch("GEMINI_API_KEY", ""),
  default_options: {
    chat_model: GEMINI_MODEL,
    embedding_model: GEMINI_EMBEDDING_MODEL
  }
)
