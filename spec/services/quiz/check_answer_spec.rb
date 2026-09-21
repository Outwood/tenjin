# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quiz::CheckAnswer, :default_creates do
  let(:user) { create(:student, school: school) }
  let(:question) { create(:question, topic: topic) }
  let(:correct_answer) { question.answers.find_by(correct: true) }
  let(:wrong_answer) { create(:answer, question: question, correct: false) }
  let(:quiz) { create(:quiz, user: user, question_order: [question.id], num_questions_asked: 1) }

  before do
    quiz.questions << question
    create(:asked_question, quiz: quiz, question: question)
    allow(Quiz::AddLeaderboardPoint).to receive(:call)
    allow(Multiplier).to receive(:for_streak).and_return(1)
  end

  it "returns a successful Result with a CheckAnswerOutcome payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(result).to be_success
    expect(result.payload).to be_a(Quiz::CheckAnswerOutcome)
  end

  it "increments streak on a correct multiple-choice answer" do
    initial_streak = quiz.streak
    described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(quiz.reload.streak).to eq(initial_streak + 1)
  end

  it "resets streak on a wrong multiple-choice answer" do
    quiz.update(streak: 4)
    described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id})
    expect(quiz.reload.streak).to eq 0
  end

  it "reports a correct verdict in the payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(result.payload.correct).to be true
  end

  it "reports an incorrect verdict in the payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id})
    expect(result.payload.correct).to be false
  end

  it "returns a failure when no answer id is provided for multiple choice" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: nil})
    expect(result).to be_failure
    expect(result.error).to eq :no_answer_provided
  end

  context "with a correct answer to another question" do
    subject(:check) { described_class.call(quiz: quiz, question: question, answer_given: {id: foreign_answer.id}) }

    let(:other_question) { create(:question, topic: topic) }
    let(:foreign_answer) { other_question.answers.find_by!(correct: true) }

    it "refuses it as no answer" do
      expect(check).to be_failure
      expect(check.error).to eq :no_answer_provided
    end

    it "leaves the question unanswered" do
      check
      expect(quiz.asked_questions.where(question: question).pluck(:correct)).to all(be_nil)
    end

    it "does not move the quiz on" do
      expect { check }.not_to change { quiz.reload.num_questions_asked }
    end
  end

  context "with a short-answer question" do
    let(:short_answer_question) { create(:short_answer_question, topic: topic) }
    let(:quiz) { create(:quiz, user: user, question_order: [short_answer_question.id], num_questions_asked: 1) }

    before do
      quiz.questions << short_answer_question
      create(:asked_question, quiz: quiz, question: short_answer_question)
    end

    it "increments streak on a match ignoring case" do
      answer = short_answer_question.answers.find_by!(correct: true)
      expect {
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: answer.text.upcase})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "ignores surrounding and repeated whitespace" do
      answer = short_answer_question.answers.find_by!(correct: true)
      padded = "  #{answer.text.gsub(" ", "   ")}\t"
      expect {
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: padded})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "resets streak on a miss" do
      quiz.update(streak: 3)
      described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: "not it"})
      expect(quiz.reload.streak).to eq 0
    end

    it "treats a blank submission as a wrong answer (success result, streak reset to 0)" do
      quiz.update(streak: 3)
      result = described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: ""})
      expect(result).to be_success
      expect(quiz.reload.streak).to eq 0
    end

    context "with an answer flagged incorrect" do
      let!(:rejected_answer) { create(:answer, question: short_answer_question, correct: false, text: "Ode to Autumn") }

      it "does not accept it" do
        quiz.update(streak: 3)
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: rejected_answer.text})
        expect(quiz.reload.streak).to eq 0
      end
    end

    context "with several accepted answers" do
      let!(:other_answer) { create(:answer, question: short_answer_question, correct: true, text: "The Autumn") }

      it "marks a submission matching any of them correct" do
        expect {
          described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: other_answer.text})
        }.to change { quiz.reload.streak }.by(1)
      end
    end
  end
end
