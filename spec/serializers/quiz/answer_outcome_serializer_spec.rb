# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quiz::AnswerOutcomeSerializer do
  it "produces a hash with the wire-format keys" do
    question = create(:question)
    outcome = Quiz::CheckAnswerOutcome.new(question: question, correct: true, streak: 3, answered_correct: 7, multiplier: 2)
    json = described_class.new(outcome).as_json
    expect(json).to include(:answer, correct: true, streak: 3, answeredCorrect: 7, multiplier: 2)
  end

  it "lists every correct answer to the question and no other" do
    question = create(:short_answer_question)
    question.answers.find_by!(correct: true).update!(text: "Paris")
    create(:answer, question: question, correct: true, text: "Lutetia")
    create(:answer, question: question, correct: false, text: "London")
    outcome = Quiz::CheckAnswerOutcome.new(question: question, correct: false, streak: 0, answered_correct: 0, multiplier: 1)
    expect(described_class.new(outcome).as_json[:answer].map(&:text)).to contain_exactly("Paris", "Lutetia")
  end
end
