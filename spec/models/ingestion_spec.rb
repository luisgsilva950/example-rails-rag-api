# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ingestion, type: :model do
  subject { build(:ingestion) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without status" do
      subject.status = nil
      expect(subject).not_to be_valid
    end

    it "is invalid without filename" do
      subject.filename = nil
      expect(subject).not_to be_valid
    end

    it "is invalid without file_path" do
      subject.file_path = nil
      expect(subject).not_to be_valid
    end

    it "is invalid with an unknown status" do
      subject.status = "invalid"
      expect(subject).not_to be_valid
      expect(subject.errors[:status]).to include("is not included in the list")
    end

    Ingestion::STATUSES.each do |valid_status|
      it "allows status '#{valid_status}'" do
        subject.status = valid_status
        expect(subject).to be_valid
      end
    end
  end

  describe "status predicates" do
    it "responds to pending?" do
      expect(build(:ingestion, status: "pending")).to be_pending
    end

    it "responds to processing?" do
      expect(build(:ingestion, status: "processing")).to be_processing
    end

    it "responds to completed?" do
      expect(build(:ingestion, status: "completed")).to be_completed
    end

    it "responds to failed?" do
      expect(build(:ingestion, status: "failed")).to be_failed
    end
  end

  describe "#mark_processing!" do
    it "transitions to processing" do
      ingestion = create(:ingestion, status: "pending")
      ingestion.mark_processing!

      expect(ingestion.reload).to be_processing
    end
  end

  describe "#mark_completed!" do
    it "transitions to completed with chunks_count" do
      ingestion = create(:ingestion, status: "processing")
      ingestion.mark_completed!(chunks_count: 5)

      ingestion.reload
      expect(ingestion).to be_completed
      expect(ingestion.chunks_count).to eq(5)
    end
  end

  describe "#mark_failed!" do
    it "transitions to failed with error_message" do
      ingestion = create(:ingestion, status: "processing")
      ingestion.mark_failed!(error_message: "Something went wrong")

      ingestion.reload
      expect(ingestion).to be_failed
      expect(ingestion.error_message).to eq("Something went wrong")
    end
  end

  describe ".by_status" do
    it "filters by status" do
      create(:ingestion, status: "pending")
      create(:ingestion, status: "completed")
      create(:ingestion, status: "completed")

      expect(Ingestion.by_status("completed").count).to eq(2)
    end
  end
end
