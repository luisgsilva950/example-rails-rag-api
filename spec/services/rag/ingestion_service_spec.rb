# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rag::IngestionService, type: :service do
  let(:llm) { instance_double(Langchain::LLM::GoogleGemini) }
  let(:service) { described_class.new(llm: llm) }
  let(:fake_embedding) { Array.new(3072) { rand(-1.0..1.0) } }

  let(:embed_response) do
    instance_double("Langchain::LLM::GoogleGeminiResponse", embedding: fake_embedding)
  end

  before do
    allow(llm).to receive(:embed).and_return(embed_response)
  end

  describe "#call" do
    context "with a valid PDF file" do
      let(:pdf_path) { Rails.root.join("spec", "fixtures", "files", "sample.pdf").to_s }
      let(:fake_reader) { instance_double(PDF::Reader) }
      let(:fake_page1) { instance_double(PDF::Reader::Page, text: "This is the first page content.") }
      let(:fake_page2) { instance_double(PDF::Reader::Page, text: "This is the second page content.") }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(pdf_path).and_return(true)
        allow(File).to receive(:extname).and_call_original
        allow(File).to receive(:extname).with(pdf_path).and_return(".pdf")
        allow(PDF::Reader).to receive(:new).with(pdf_path).and_return(fake_reader)
        allow(fake_reader).to receive(:pages).and_return([ fake_page1, fake_page2 ])
      end

      it "extracts text, chunks it, and stores in PostgreSQL" do
        expect { service.call(file_path: pdf_path) }.to change(Document, :count).by(1)

        result = service.call(file_path: pdf_path)
        expect(result[:status]).to eq("success")
        expect(result[:chunks_count]).to be > 0
      end

      it "stores chunks with embeddings and source" do
        service.call(file_path: pdf_path)

        document = Document.last
        expect(document.content).to be_present
        expect(document.source).to eq("sample.pdf")
        expect(document.embedding).to be_present
      end
    end

    context "with a valid TXT file" do
      let(:txt_path) { Rails.root.join("tmp", "test_ingestion.txt").to_s }

      before do
        FileUtils.mkdir_p(File.dirname(txt_path))
        File.write(txt_path, "This is plain text content for ingestion.")
      end

      after { FileUtils.rm_f(txt_path) }

      it "reads text directly and stores chunks" do
        result = service.call(file_path: txt_path)

        expect(result[:status]).to eq("success")
        expect(result[:chunks_count]).to eq(1)
        expect(Document.last.content).to include("plain text content")
        expect(Document.last.source).to eq("test_ingestion.txt")
      end
    end

    context "with a valid JSON file" do
      let(:json_path) { Rails.root.join("tmp", "test_ingestion.json").to_s }
      let(:json_content) { { title: "Ruby Guide", body: "Ruby is a dynamic language." }.to_json }

      before do
        FileUtils.mkdir_p(File.dirname(json_path))
        File.write(json_path, json_content)
      end

      after { FileUtils.rm_f(json_path) }

      it "reads JSON content as text and stores chunks" do
        result = service.call(file_path: json_path)

        expect(result[:status]).to eq("success")
        expect(result[:chunks_count]).to eq(1)
        expect(Document.last.content).to include("Ruby is a dynamic language")
      end
    end

    context "with a valid Markdown file" do
      let(:md_path) { Rails.root.join("tmp", "test_ingestion.md").to_s }

      before do
        FileUtils.mkdir_p(File.dirname(md_path))
        File.write(md_path, "# Hello\n\nThis is **markdown** content.")
      end

      after { FileUtils.rm_f(md_path) }

      it "reads markdown as text and stores chunks" do
        result = service.call(file_path: md_path)

        expect(result[:status]).to eq("success")
        expect(result[:chunks_count]).to eq(1)
        expect(Document.last.content).to include("markdown")
      end
    end

    context "when the file does not exist" do
      it "raises an ArgumentError" do
        expect {
          service.call(file_path: "/nonexistent/file.pdf")
        }.to raise_error(ArgumentError, /File not found/)
      end
    end

    context "with an unsupported file type" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with("/some/file.csv").and_return(true)
      end

      it "raises an ArgumentError" do
        expect {
          service.call(file_path: "/some/file.csv")
        }.to raise_error(ArgumentError, /Unsupported file type/)
      end
    end
  end

  describe "chunking logic" do
    it "creates overlapping chunks" do
      text = "A" * 100
      chunks = service.send(:split_into_chunks, text, chunk_size: 40, chunk_overlap: 10)

      expect(chunks.length).to eq(4)
      expect(chunks.first.length).to eq(40)
    end

    it "handles text shorter than chunk_size" do
      text = "Short text"
      chunks = service.send(:split_into_chunks, text, chunk_size: 1000, chunk_overlap: 200)

      expect(chunks.length).to eq(1)
      expect(chunks.first).to eq("Short text")
    end

    it "skips empty chunks" do
      text = "Hi"
      chunks = service.send(:split_into_chunks, text, chunk_size: 2, chunk_overlap: 0)

      expect(chunks).to all(satisfy { |c| !c.strip.empty? })
    end
  end
end
