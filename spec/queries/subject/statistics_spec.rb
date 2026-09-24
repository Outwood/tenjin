# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subject::Statistics, :default_creates do
  subject(:stats) { described_class.new(quiz_subject) }

  let(:question) { create(:question, topic: topic) }

  describe "#asked_questions" do
    before do
      create(:question_statistic, question: question, number_asked: 7)
      create(:question_statistic, question: create(:question), number_asked: 50)
    end

    it "totals the subject's question statistics" do
      expect(stats.asked_questions).to eq 7
    end

    it "is memoized" do
      stats.asked_questions
      expect(QuestionStatistic).not_to receive(:joins)
      stats.asked_questions
    end
  end

  describe "#asked_questions_this_week" do
    before do
      create_list(:asked_question, 2, :answered, question: question)
      create(:asked_question, question: question)
      create(:asked_question, :answered, question: question, answered_at: 2.weeks.ago)
      create(:asked_question, :answered, question: create(:question))
    end

    it "counts only this week's answers to the subject's questions" do
      expect(stats.asked_questions_this_week).to eq 2
    end

    it "is memoized" do
      stats.asked_questions_this_week
      expect(AskedQuestion).not_to receive(:joins)
      stats.asked_questions_this_week
    end
  end
end
