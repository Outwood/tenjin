# frozen_string_literal: true

require "rails_helper"

RSpec.describe Homework::UpdateHomeworkProgress, :default_creates do
  let!(:enrollment) { create(:enrollment, classroom: classroom, user: student) }
  let!(:homework) { create(:homework, topic: topic, classroom: classroom, required: mark_required) }
  let(:progress) { HomeworkProgress.find_by(homework: homework) }

  context "when the required mark is 100" do
    let(:mark_required) { 100 }

    let(:quiz_full_marks) do
      create(:quiz, subject: quiz_subject, topic: topic, num_questions_asked: 10,
        answered_correct: 10, active: false, user: student)
    end

    let(:quiz_7_out_of_10) do
      create(:quiz, subject: quiz_subject, topic: topic, num_questions_asked: 10,
        answered_correct: 7, active: false, user: student)
    end

    it "marks the homework complete and returns success with the flag" do
      result = described_class.call(quiz: quiz_full_marks)
      expect(result).to be_success
      expect(result.payload).to eq(completed: true)
      expect(progress.reload).to be_completed
    end

    it "records when the homework was completed" do
      described_class.call(quiz: quiz_full_marks)
      expect(progress.reload.completed_at).to be_within(1.minute).of(Time.current)
    end

    it "records partial progress and returns success with completed false below the required mark" do
      result = described_class.call(quiz: quiz_7_out_of_10)
      expect(result).to be_success
      expect(result.payload).to eq(completed: false)
      expect(progress.reload).to have_attributes(completed: false, progress: 70)
    end

    it "ignores progress that is less than current progress" do
      described_class.call(quiz: quiz_full_marks)
      described_class.call(quiz: quiz_7_out_of_10)
      expect(progress.reload.progress).to eq(100)
    end
  end

  context "when the required mark is 30" do
    let(:mark_required) { 30 }

    let(:quiz_1_out_of_3) do
      create(:quiz, subject: quiz_subject, topic: topic, num_questions_asked: 3,
        answered_correct: 1, active: false, user: student)
    end

    it "truncates fractional percentages to the nearest integer" do
      described_class.call(quiz: quiz_1_out_of_3)
      expect(progress.reload.progress).to eq(33)
    end

    context "with the homework already completed" do
      let(:completed_at) { 2.days.ago.round }
      let(:quiz_full_marks) do
        create(:quiz, subject: quiz_subject, topic: topic, num_questions_asked: 10,
          answered_correct: 10, active: false, user: student)
      end

      before { progress.update!(progress: 40, completed: true, completed_at: completed_at) }

      it "raises the score but keeps the completion time" do
        described_class.call(quiz: quiz_full_marks)
        expect(progress.reload).to have_attributes(progress: 100, completed_at: completed_at)
      end
    end

    # As a second quiz finishing at the same moment would see it: loaded before the first completed it
    context "with a row read before another quiz completed it" do
      let!(:stale_progress) { HomeworkProgress.find_by!(homework: homework) }
      let(:completed_at) { 2.days.ago.round }

      before do
        progress.update!(progress: 40, completed: true, completed_at: completed_at)
        rows = double(:rows)
        allow(rows).to receive(:find_each).and_yield(stale_progress)
        allow_any_instance_of(described_class).to receive(:homework_progresses).and_return(rows)
      end

      it "keeps the first completion's time" do
        described_class.call(quiz: quiz_1_out_of_3)
        expect(progress.reload.completed_at).to eq(completed_at)
      end
    end
  end

  context "when a homework progress record cannot be saved" do
    let(:mark_required) { 100 }

    let(:quiz_full_marks) do
      create(:quiz, subject: quiz_subject, topic: topic, num_questions_asked: 10,
        answered_correct: 10, active: false, user: student)
    end

    before do
      errors_double = instance_double(ActiveModel::Errors, full_messages: ["Progress is invalid"])
      allow_any_instance_of(HomeworkProgress).to receive(:save).and_return(false)
      allow_any_instance_of(HomeworkProgress).to receive(:errors).and_return(errors_double)
    end

    it "returns a failure result" do
      result = described_class.call(quiz: quiz_full_marks)
      expect(result).to be_failure
      expect(result.error).to match(/Progress is invalid/)
    end
  end
end
