# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::StyrofoamEarthquakeTool do
  let(:tool) { described_class.new }

  describe ".function_schemas" do
    it "defines the explain function with correct parameters" do
      schemas = described_class.function_schemas.to_google_gemini_format
      explain_fn = schemas.find { |f| f[:name].to_s.end_with?("explain") }

      expect(explain_fn).to be_present
      expect(explain_fn[:description]).to include("Styrofoam Earthquake")
      expect(explain_fn[:parameters][:properties]).to have_key(:question)
      expect(explain_fn[:parameters][:required]).to eq([ "question" ])
    end
  end

  describe "#explain" do
    it "returns the Styrofoam Earthquake definition" do
      result = tool.explain(question: "What is a Styrofoam Earthquake?")

      expect(result).to eq(described_class::DEFINITION)
    end

    it "returns the same definition regardless of the question" do
      result = tool.explain(question: "Tell me about Styrofoam Earthquake")

      expect(result).to include("noise")
      expect(result).to include("real impact")
    end
  end
end
