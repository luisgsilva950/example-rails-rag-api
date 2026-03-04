# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  subject { build(:message) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without a session_id" do
      subject.session_id = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:session_id]).to include("can't be blank")
    end

    it "is invalid without a role" do
      subject.role = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:role]).to include("can't be blank")
    end

    it "is invalid with an unrecognized role" do
      subject.role = "unknown"
      expect(subject).not_to be_valid
      expect(subject.errors[:role]).to include("is not included in the list")
    end

    it "is invalid without content" do
      subject.content = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:content]).to include("can't be blank")
    end

    it "accepts valid roles" do
      %w[user assistant system].each do |role|
        subject.role = role
        expect(subject).to be_valid
      end
    end
  end

  describe "scopes" do
    describe ".for_session" do
      let(:session_id) { SecureRandom.uuid }
      let!(:msg1) { create(:message, session_id: session_id, created_at: 1.minute.ago) }
      let!(:msg2) { create(:message, session_id: session_id, created_at: Time.current) }
      let!(:other_msg) { create(:message, session_id: SecureRandom.uuid) }

      it "returns messages for the given session ordered by created_at" do
        result = Message.for_session(session_id)
        expect(result).to eq([ msg1, msg2 ])
      end

      it "does not include messages from other sessions" do
        result = Message.for_session(session_id)
        expect(result).not_to include(other_msg)
      end
    end
  end

  describe "constants" do
    it "defines valid ROLES" do
      expect(Message::ROLES).to eq(%w[user assistant system])
    end
  end
end
