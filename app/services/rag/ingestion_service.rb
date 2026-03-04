# frozen_string_literal: true

module Rag
  # Ingests documents (PDF, TXT, JSON) into PostgreSQL with pgvector embeddings.
  class IngestionService
    DEFAULT_CHUNK_SIZE = 1000
    DEFAULT_CHUNK_OVERLAP = 200
    SUPPORTED_EXTENSIONS = %w[.pdf .txt .json .md].freeze

    attr_reader :llm

    def initialize(llm: GEMINI_LLM)
      @llm = llm
    end

    def call(file_path:, chunk_size: DEFAULT_CHUNK_SIZE, chunk_overlap: DEFAULT_CHUNK_OVERLAP)
      validate_file!(file_path)
      text = extract_text(file_path)
      chunks = split_into_chunks(text, chunk_size: chunk_size, chunk_overlap: chunk_overlap)
      store_chunks(chunks, source: File.basename(file_path))
      { chunks_count: chunks.size, chunks: chunks, status: "success" }
    end

    private

    def validate_file!(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)
      raise ArgumentError, "Unsupported file type. Accepted: #{SUPPORTED_EXTENSIONS.join(', ')}" unless supported?(file_path)
    end

    def supported?(file_path)
      SUPPORTED_EXTENSIONS.include?(File.extname(file_path).downcase)
    end

    def extract_text(file_path)
      case File.extname(file_path).downcase
      when ".pdf" then extract_pdf(file_path)




      else File.read(file_path)
      end
    end

    def extract_pdf(file_path)
      reader = PDF::Reader.new(file_path)
      reader.pages.map(&:text).join("\n")
    end

    def split_into_chunks(text, chunk_size:, chunk_overlap:)
      step = chunk_size - chunk_overlap

      (0...text.length).step(step).filter_map do |start|
        chunk = text[start, chunk_size]
        chunk unless chunk.strip.empty?
      end
    end

    def store_chunks(chunks, source:)
      chunks.each do |chunk|
        embedding = llm.embed(text: chunk).embedding
        Document.create!(content: chunk, source: source, embedding: embedding)
      end
    end
  end
end
