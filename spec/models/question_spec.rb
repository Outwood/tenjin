# frozen_string_literal: true

require "rails_helper"

RSpec.describe Question, :default_creates do
  let(:question) { create(:question, topic: topic) }
  let(:mismatched_question) { build(:question, lesson: create(:lesson), topic: topic) }

  it "has a valid factory" do
    expect(build(:question)).to be_valid
  end

  describe "validations" do
    subject { build(:question) }

    it { is_expected.to belong_to(:topic) }
    it { is_expected.to have_many(:answers) }
    it { is_expected.to belong_to(:lesson).optional }

    it "requires a question type" do
      expect(build(:question, question_type: nil)).to be_invalid
    end

    it "requires the question to be active or inactive" do
      expect(build(:question, active: nil)).to be_invalid
    end
  end

  it "does not allow a mismatched lesson and topic" do
    expect(mismatched_question).not_to be_valid
  end

  context "with a boolean question" do
    let(:boolean_question) { build(:boolean_question) }

    context "when true answer precedes false" do
      before do
        boolean_question
        boolean_question.answers.first.update!(text: "TruE")
        create(:answer, question: question, correct: true, text: "fAlsE")
      end

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when false answer precedes true" do
      before do
        boolean_question
        boolean_question.answers.first.update!(text: "FaLsE")
        create(:answer, question: question, correct: true, text: "TrUe")
      end

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "with non-boolean answer text" do
      before { boolean_question.answers.first.text = "Maybe" }

      it "is invalid" do
        expect(boolean_question).not_to be_valid
      end
    end
  end

  describe "answers marked for destruction" do
    let(:correct_answer) { question.answers.find_by!(correct: true) }

    context "when the only answer is marked" do
      before { question.reload.assign_attributes(answers_attributes: [{id: correct_answer.id, _destroy: "1"}]) }

      it "is invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:base]).to include("Question must have at least one correct answer.")
      end
    end

    context "when the only correct answer is marked" do
      before do
        create(:answer, question: question, correct: false)
        question.reload.assign_attributes(answers_attributes: [{id: correct_answer.id, _destroy: "1"}])
      end

      it "is invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:base]).to include("Question must have at least one correct answer.")
      end
    end

    context "when an incorrect answer is marked" do
      before do
        incorrect_answer = create(:answer, question: question, correct: false)
        question.reload.assign_attributes(answers_attributes: [{id: incorrect_answer.id, _destroy: "1"}])
      end

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when a boolean question's answer is marked" do
      let(:question) { create(:boolean_question, topic: topic) }

      before do
        false_answer = question.answers.find_by!(correct: false)
        question.reload.assign_attributes(answers_attributes: [{id: false_answer.id, _destroy: "1"}])
      end

      it "is invalid" do
        expect(question).not_to be_valid
        expect(question.errors[:base]).to include("Boolean question must contain two answers")
      end
    end
  end

  it "removes the question from the database when destroyed" do
    question
    expect { question.destroy }.to change(described_class, :count).by(-1)
  end

  describe ".check_boolean" do
    context "when changing a question type to a boolean question" do
      let(:question) { create(:question, question_type: "multiple") }

      # update_attribute intentional: update! runs the "two answers" validation before
      # the check_boolean callback creates them, so validation fires before the callback can run.
      before { question.update_attribute(:question_type, "boolean") }

      it "replaces all existing answers with exactly two boolean answers" do
        expect(question.reload.answers).to contain_exactly(
          have_attributes(text: "False", correct: false),
          have_attributes(text: "True", correct: false)
        )
      end
    end

    context "when not changing to a boolean question type" do
      let(:question) { create(:question, question_type: "multiple") }

      it "does not replace existing answers" do
        expect { question.update!(question_text: "updated text") }
          .not_to change { question.reload.answers.pluck(:id) }
      end
    end
  end

  describe ".check_short_answer" do
    let(:question) { create(:question, question_type: "multiple") }
    let(:answer) { create(:answer, question: question, correct: false) }

    context "when switching a question to a short answer question" do
      before do
        answer
        question.update!(question_type: "short_answer")
      end

      it "marks all existing answers as correct" do
        expect(answer.reload.correct).to be(true)
      end
    end

    context "when not switching to a short answer question" do
      let!(:answer) { create(:answer, question: question, correct: false) }

      it "does not mark existing answers as correct" do
        expect { question.update!(question_text: "updated text") }
          .not_to change { answer.reload.correct }
      end
    end
  end
end
