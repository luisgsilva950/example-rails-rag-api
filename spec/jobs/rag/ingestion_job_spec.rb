# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::IngestionJob, type: :job do
  let(:fake_embedding) { Array.new(3072) { rand(-1.0..1.0) } }
  let(:embed_response) { instance_double("EmbedResponse", embedding: fake_embedding) }
  let(:file_path) { Rails.root.join("tmp", "test_job_ingestion.txt").to_s }

  before do
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "Background job ingestion content.")
    allow(GEMINI_LLM).to receive(:embed).and_return(embed_response)
  end

  after { FileUtils.rm_f(file_path) }

  describe "#perform" do
    it "processes the ingestion and marks it completed" do
      ingestion = create(:ingestion, file_path: file_path)

      described_class.new.perform(ingestion.id)

      ingestion.reload
      expect(ingestion).to be_completed
      expect(ingestion.chunks_count).to eq(1)
      expect(Document.last.content).to include("Background job ingestion content")
    end

    it "transitions through processing state" do
      ingestion = create(:ingestion, file_path: file_path)

      allow_any_instance_of(Rag::IngestionService).to receive(:call).and_wrap_original do |method, **args|
        expect(ingestion.reload).to be_processing
        method.call(**args)
      end

      described_class.new.perform(ingestion.id)
    end

    it "marks the ingestion as failed on error" do
      ingestion = create(:ingestion, file_path: "/nonexistent/file.txt")

      described_class.new.perform(ingestion.id)

      ingestion.reload
      expect(ingestion).to be_failed
      expect(ingestion.error_message).to include("File not found")
    end

    it "skips non-pending ingestions" do
      ingestion = create(:ingestion, status: "completed", file_path: file_path)

      expect { described_class.new.perform(ingestion.id) }.not_to change(Document, :count)
    end

    it "enqueues on the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
