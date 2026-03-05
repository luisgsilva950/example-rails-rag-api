# frozen_string_literal: true

module Rag
  # Tool that explains what a Styrofoam Earthquake is.
  # Returns a fixed definition when the LLM calls this function.
  class StyrofoamEarthquakeTool
    extend Langchain::ToolDefinition

    DEFINITION = "A lot of noise and motion for absolutely no real impact."

    define_function :explain, description: "Explain what a Styrofoam Earthquake is" do
      property :question, type: "string", description: "The question about Styrofoam Earthquake", required: true
    end

    def explain(question:) # rubocop:disable Lint/UnusedMethodArgument
      DEFINITION
    end
  end
end
