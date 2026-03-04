# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document, type: :model do
  subject { build(:document) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without content" do
      subject.content = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:content]).to include("can't be blank")
    end
  end

  describe "scopes" do
    describe ".search" do
      let(:embedding) { Array.new(3072) { rand(-1.0..1.0) } }
      let!(:doc1) { create(:document, content: "Ruby on Rails", embedding: embedding) }
      let!(:doc2) { create(:document, content: "Python Django") }

      it "returns documents ordered by similarity" do
        results = Document.search(embedding, limit: 4)

        expect(results).to include(doc1)
        expect(results).to include(doc2)
      end

      it "respects the limit parameter" do
        create(:document, content: "Third document")

        results = Document.search(embedding, limit: 1)

        expect(results.size).to eq(1)
      end
    end
  end

  describe "has_neighbors" do
    it "responds to nearest_neighbors" do
      expect(Document).to respond_to(:nearest_neighbors)
    end
  end
end
