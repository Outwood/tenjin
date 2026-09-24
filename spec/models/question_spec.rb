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
  end

  it "does not allow a mismatched lesson and topic" do
    expect(mismatched_question).not_to be_valid
  end

  context "with a boolean question" do
    let(:boolean_question) { build(:boolean_question) }

    context "when true answer precedes false" do
      before do
        boolean_question.answers.first.text = "TruE"
        boolean_question.answers.last.text = "fAlsE"
      end

      it "is valid" do
        expect(boolean_question).to be_valid
      end
    end

    context "when false answer precedes true" do
      before do
        boolean_question.answers.first.text = "FaLsE"
        boolean_question.answers.last.text = "TrUe"
      end

      it "is valid" do
        expect(boolean_question).to be_valid
      end
    end

    context "with labels carrying stray whitespace" do
      before do
        boolean_question.answers.first.text = " true "
        boolean_question.answers.last.text = "false\n"
      end

      it "is valid" do
        expect(boolean_question).to be_valid
      end
    end

    context "with two labels meaning true" do
      before do
        boolean_question.answers.first.text = "True"
        boolean_question.answers.last.text = "true"
      end

      it "is invalid" do
        expect(boolean_question).to be_invalid
      end
    end

    context "with non-boolean answer text" do
      before { boolean_question.answers.first.text = "Maybe" }

      it "is invalid" do
        expect(boolean_question).not_to be_valid
      end
    end
  end

  describe "answer texts" do
    let(:question) { build(:question, topic: topic) }

    let(:first_text) { "Max Jones" }

    before do
      question.answers.first.text = first_text
      question.answers.build(text: repeated_text)
    end

    context "with options differing only in spacing" do
      let(:repeated_text) { " Max  Jones " }

      it "is invalid" do
        expect(question).to be_invalid
        expect(question.errors[:base]).to include("Answers must be different from each other")
      end
    end

    context "with options differing in case" do
      let(:repeated_text) { "max jones" }

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "with short answers differing only in case" do
      let(:question) { build(:short_answer_question, topic: topic) }
      let(:repeated_text) { "max jones" }

      it "is invalid" do
        expect(question).to be_invalid
        expect(question.errors[:base]).to include("Answers must be different from each other")
      end
    end

    context "with two blank answers" do
      let(:first_text) { "" }
      let(:repeated_text) { "" }

      it "reports no repeat" do
        question.validate
        expect(question.errors[:base]).not_to include("Answers must be different from each other")
      end
    end

    context "with the repeat marked for destruction" do
      let(:repeated_text) { "Max Jones" }

      before { question.answers.last.mark_for_destruction }

      it "is valid" do
        expect(question).to be_valid
      end
    end
  end

  context "when two options swap texts" do
    let(:question) { create(:question, topic: topic) }
    let!(:first_answer) { question.answers.first.tap { |answer| answer.update!(text: "Paris") } }
    let!(:second_answer) { create(:answer, question: question, text: "Lyon") }

    before do
      question.reload.update!(answers_attributes: [
        {id: first_answer.id, text: "Lyon"}, {id: second_answer.id, text: "Paris"}
      ])
    end

    it "saves both" do
      expect { check_deferred_constraints! }.not_to raise_error
      expect(question.answers.order(:id).pluck(:text)).to eq(%w[Lyon Paris])
    end
  end

  context "when another save adds the same option first" do
    let(:question) { create(:question, topic: topic) }
    let(:stale_copy) { described_class.find(question.id).tap { |copy| copy.answers.load } }

    before do
      stale_copy
      question.answers.create!(text: "Paris")
    end

    it "reports the repeat from save" do
      stale_copy.answers.build(text: "Paris")
      expect(stale_copy.save).to be false
      expect(stale_copy.errors[:base]).to include("Answers must be different from each other")
    end

    it "reports the repeat from update" do
      expect(stale_copy.update(answers_attributes: [{text: "Paris"}])).to be false
      expect(stale_copy.errors[:base]).to include("Answers must be different from each other")
    end

    it "raises it as invalid from save!" do
      stale_copy.answers.build(text: "Paris")
      expect { stale_copy.save! }.to raise_error(ActiveRecord::RecordInvalid, /Answers must be different/)
    end

    it "leaves a surrounding transaction usable" do
      described_class.transaction do
        stale_copy.answers.build(text: "Paris")
        stale_copy.save
        expect { described_class.count }.not_to raise_error
      end
    end
  end

  context "when the caller has made the answer text check immediate" do
    let(:question) { create(:question, topic: topic) }

    before do
      check_deferred_constraints!
      question.answers.build(text: "Lyon")
      question.save!
    end

    it "leaves it immediate" do
      expect { create(:answer, question: question, text: "Lyon") }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  context "when a save writes no answer text" do
    let!(:question) { create(:question, topic: topic) }
    let(:statements) { [] }

    before do
      record = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(record, "sql.active_record") { question.update!(active: false) }
    end

    it "runs no answer text check" do
      expect(statements.grep(/SET CONSTRAINTS/)).to be_empty
    end
  end

  context "with a stored option carrying stray whitespace" do
    let(:question) { create(:question, topic: topic) }

    before do
      # Raw SQL, since any write through the model normalises
      described_class.connection.execute("UPDATE answers SET text = ' Paris' WHERE question_id = #{question.id}")
      question.reload.answers.build(text: "Paris")
    end

    it "counts a new copy as a repeat" do
      expect(question).to be_invalid
      expect(question.errors[:base]).to include("Answers must be different from each other")
    end
  end

  context "when another unique index refuses the save" do
    before do
      described_class.connection.execute("CREATE UNIQUE INDEX one_question_per_topic ON questions (topic_id)")
      create(:question, topic: topic)
    end

    it "raises rather than blaming the answers" do
      expect { build(:question, topic: topic).save }.to raise_error(ActiveRecord::RecordNotUnique)
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
