# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeactivateStaleQuizzesJob, :default_creates do
  context "with a quiz untouched for a day" do
    let!(:quiz) { create(:quiz, user: student, updated_at: 2.days.ago) }

    it "deactivates it" do
      expect { described_class.perform_now }.to change { quiz.reload.active }.from(true).to(false)
    end
  end

  context "with a quiz answered today" do
    let!(:quiz) { create(:quiz, user: student) }

    it "leaves it active" do
      expect { described_class.perform_now }.not_to change { quiz.reload.active }
    end
  end

  context "with attempts on an inactive quiz" do
    let(:quiz) { create(:quiz, user: student, active: false, updated_at: 2.days.ago) }

    before do
      create(:asked_question, :answered, quiz: quiz, updated_at: 2.days.ago)
      create(:asked_question, quiz: quiz, updated_at: 2.days.ago)
    end

    it "keeps them, answered or not" do
      expect { described_class.perform_now }.not_to change(AskedQuestion, :count).from(2)
    end
  end
end
