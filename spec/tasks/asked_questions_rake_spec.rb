# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe "asked_questions rake tasks", :default_creates do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("asked_questions:count_uncounted") }

  before { allow($stdout).to receive(:puts) }

  def run_task
    Rake::Task["asked_questions:count_uncounted"].tap(&:reenable).invoke
  end

  describe "asked_questions:count_uncounted" do
    let(:question) { create(:question, topic: topic) }
    let(:quiz) { create(:quiz, user: student) }

    context "with an answer recorded before answered_at existed" do
      let(:recorded_at) { 2.weeks.ago.change(usec: 0) }
      let!(:row) { create(:asked_question, quiz: quiz, question: question, correct: true, updated_at: recorded_at) }

      it "marks it answered when it was recorded" do
        expect { run_task }.to change { row.reload.answered_at }.from(nil).to(recorded_at)
      end

      it "counts it for the question and for the pupil in that week" do
        run_task
        expect(QuestionStatistic.find_by!(question: question)).to have_attributes(number_asked: 1, number_correct: 1)
        expect(UserStatistic.find_by!(user: student, week_beginning: recorded_at.to_date.beginning_of_week)
          .questions_answered).to eq 1
      end

      it "reports how many it counted" do
        run_task
        expect($stdout).to have_received(:puts).with("counted 1 answer(s) recorded before answered_at")
      end

      it "counts nothing on a second run" do
        run_task
        expect { run_task }.not_to change { QuestionStatistic.find_by!(question: question).number_asked }
      end
    end

    context "with an unanswered row" do
      let!(:row) { create(:asked_question, quiz: quiz, question: question) }

      it "leaves it unanswered and uncounted" do
        expect { run_task }.to not_change { row.reload.answered_at }.and not_change(QuestionStatistic, :count)
      end
    end

    context "with an answer already counted when claimed" do
      before { create(:asked_question, :answered, quiz: quiz, question: question, answered_at: 1.hour.ago) }

      it "counts nothing" do
        expect { run_task }.not_to change(QuestionStatistic, :count)
      end
    end
  end
end
