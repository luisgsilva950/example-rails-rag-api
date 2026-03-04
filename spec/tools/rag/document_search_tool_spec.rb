# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::DocumentSearchTool do
  let(:llm) { instance_double(Langchain::LLM::GoogleGemini) }
  let(:tool) { described_class.new(llm: llm) }
  let(:fake_embedding) { Array.new(3072) { rand(-1.0..1.0) } }

  let(:embed_response) do
    instance_double("Langchain::LLM::GoogleGeminiResponse", embedding: fake_embedding)
  end

  before do
    allow(llm).to receive(:embed).and_return(embed_response)
  end

  describe ".function_schemas" do
    it "defines the search function with correct parameters" do
      schemas = described_class.function_schemas.to_google_gemini_format
      search_fn = schemas.find { |f| f[:name].to_s.end_with?("search") }

      expect(search_fn).to be_present
      expect(search_fn[:description]).to include("Search for relevant documents")
      expect(search_fn[:parameters][:properties]).to have_key(:query)
      expect(search_fn[:parameters][:properties]).to have_key(:limit)
      expect(search_fn[:parameters][:required]).to eq([ "query" ])
    end
  end

  describe "#search" do
    let!(:doc1) { create(:document, content: "Ruby on Rails is a web framework.", embedding: fake_embedding) }
    let!(:doc2) { create(:document, content: "Rails uses the MVC pattern.", embedding: fake_embedding) }

    it "returns formatted document results" do
      result = tool.search(query: "Rails framework")

      expect(result).to include("[1]")
      expect(result).to include("[2]")
      expect(llm).to have_received(:embed).with(text: "Rails framework")
    end

    it "respects the limit parameter" do
      result = tool.search(query: "Rails", limit: 1)

      expect(result).to include("[1]")
      expect(result).not_to include("[2]")
    end

    it "returns fallback message when no documents found" do
      Document.delete_all
      result = tool.search(query: "nonexistent topic")

      expect(result).to eq("No relevant documents found.")
    end
  end
end
