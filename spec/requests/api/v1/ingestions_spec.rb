# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Ingestions", type: :request do
  describe "POST /api/v1/ingestions" do
    context "with a valid PDF file" do
      let(:pdf_file) do
        fixture_file_upload(Rails.root.join("spec", "fixtures", "files", "sample.pdf"), "application/pdf")
      end

      before do
        fixture_dir = Rails.root.join("spec", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)

        pdf_path = fixture_dir.join("sample.pdf")
        next if File.exist?(pdf_path)

        File.open(pdf_path, "wb") do |f|
          f.write("%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n190\n%%EOF\n")
        end
      end

      it "returns 202 accepted with ingestion_id" do
        post "/api/v1/ingestions", params: { file: pdf_file }

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Document queued for ingestion")
        expect(json["ingestion_id"]).to be_present
        expect(json["status"]).to eq("pending")
        expect(json["filename"]).to eq("sample.pdf")
      end

      it "creates an Ingestion record" do
        expect { post "/api/v1/ingestions", params: { file: pdf_file } }
          .to change(Ingestion, :count).by(1)
      end

      it "enqueues an IngestionJob" do
        expect { post "/api/v1/ingestions", params: { file: pdf_file } }
          .to have_enqueued_job(Rag::IngestionJob)
      end
    end

    context "with a valid TXT file" do
      let(:txt_file) do
        fixture_file_upload(Rails.root.join("spec", "fixtures", "files", "sample.txt"), "text/plain")
      end

      before do
        fixture_dir = Rails.root.join("spec", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)
        File.write(fixture_dir.join("sample.txt"), "Just a text file")
      end

      it "returns 202 accepted" do
        post "/api/v1/ingestions", params: { file: txt_file }

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Document queued for ingestion")
        expect(json["filename"]).to eq("sample.txt")
      end
    end

    context "with a valid JSON file" do
      let(:json_file) do
        fixture_file_upload(Rails.root.join("spec", "fixtures", "files", "sample.json"), "application/json")
      end

      before do
        fixture_dir = Rails.root.join("spec", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)
        File.write(fixture_dir.join("sample.json"), { title: "Test" }.to_json)
      end

      it "returns 202 accepted" do
        post "/api/v1/ingestions", params: { file: json_file }

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Document queued for ingestion")
        expect(json["filename"]).to eq("sample.json")
      end
    end

    context "with a valid Markdown file" do
      let(:md_file) do
        fixture_file_upload(Rails.root.join("spec", "fixtures", "files", "sample.md"), "text/markdown")
      end

      before do
        fixture_dir = Rails.root.join("spec", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)
        File.write(fixture_dir.join("sample.md"), "# Test\n\nMarkdown content.")
      end

      it "returns 202 accepted" do
        post "/api/v1/ingestions", params: { file: md_file }

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Document queued for ingestion")
        expect(json["filename"]).to eq("sample.md")
      end
    end

    context "without a file parameter" do
      it "returns 400 bad request" do
        post "/api/v1/ingestions", params: {}

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["message"]).to include("File parameter is required")
      end
    end

    context "with an unsupported file type" do
      let(:csv_file) do
        fixture_file_upload(Rails.root.join("spec", "fixtures", "files", "sample.csv"), "text/csv")
      end

      before do
        fixture_dir = Rails.root.join("spec", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)
        File.write(fixture_dir.join("sample.csv"), "col1,col2\nval1,val2")
      end

      it "returns 400 bad request" do
        post "/api/v1/ingestions", params: { file: csv_file }

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["message"]).to include("Unsupported file type")
      end
    end
  end

  describe "GET /api/v1/ingestions/:id" do
    context "when ingestion is pending" do
      it "returns the ingestion status" do
        ingestion = create(:ingestion, status: "pending")

        get "/api/v1/ingestions/#{ingestion.id}"

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["id"]).to eq(ingestion.id)
        expect(json["status"]).to eq("pending")
        expect(json["filename"]).to eq(ingestion.filename)
      end
    end

    context "when ingestion is completed" do
      it "returns status with chunks_count" do
        ingestion = create(:ingestion, status: "completed", chunks_count: 10)

        get "/api/v1/ingestions/#{ingestion.id}"

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("completed")
        expect(json["chunks_count"]).to eq(10)
      end
    end

    context "when ingestion has failed" do
      it "returns status with error_message" do
        ingestion = create(:ingestion, status: "failed", error_message: "File not found")

        get "/api/v1/ingestions/#{ingestion.id}"

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("failed")
        expect(json["error_message"]).to eq("File not found")
      end
    end

    context "when ingestion does not exist" do
      it "returns 500" do
        get "/api/v1/ingestions/999999"

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
