# frozen_string_literal: true

class Quiz::CheckAnswer < ApplicationCommand
  def initialize(quiz:, question:, answer_given:)
    @quiz = quiz
    @question = question
    @asked_question = AskedQuestion.find_by(quiz: @quiz, question: @question)
    @answer_given = answer_given
  end

  def call
    return failure(:no_answer_provided) if no_answer?

    # A refused save undoes the verdict and points with it, so a retry scores afresh
    ApplicationRecord.transaction do
      if claim_question
        score_answer
        Quiz::MoveQuizForward.call(quiz: @quiz)
        @quiz.save!
      else
        report_earlier_answer
      end
    end

    success(Quiz::CheckAnswerOutcome.new(
      question: @question,
      correct: @correct,
      streak: @quiz.streak,
      answered_correct: @quiz.answered_correct,
      multiplier: Multiplier.for_streak(@quiz.streak)
    ))
  end

  private

  # Only one of the question's own answers counts as an answer
  def no_answer?
    !@question.short_answer? && chosen_answer.nil?
  end

  def chosen_answer
    @chosen_answer ||= @question.answers.find_by(id: @answer_given[:id])
  end

  # Records the verdict only while the question is unanswered. A parallel
  # submission's write holds the row until it commits, so exactly one of them scores.
  def claim_question
    @correct = verdict
    return true if @correct.nil?

    AskedQuestion.where(id: @asked_question.id, correct: nil)
      .update_all(correct: @correct, updated_at: Time.current) == 1
  end

  # A parallel submission answered first, so report what it recorded
  def report_earlier_answer
    @quiz.reload
    @correct = @asked_question.reload.correct
  end

  # nil when a short-answer question accepts nothing, so there is no verdict to record
  def verdict
    return chosen_answer.correct unless @question.short_answer?

    accepted = Answer.where(question_id: @question, correct: true).pluck(:text)
    return if accepted.empty?

    guess = normalise(@answer_given[:short_answer])
    accepted.any? { |text| guess.casecmp?(normalise(text)) }
  end

  # Stray spacing is never what separates a right answer from a wrong one
  def normalise(text)
    text.to_s.strip.gsub(/\s+/, " ")
  end

  def score_answer
    case @correct
    when true then process_correct_answer
    when false then @quiz.streak = 0
    end
  end

  def process_correct_answer
    @quiz.answered_correct += 1
    @quiz.streak += 1
    Quiz::AddLeaderboardPoint.call(quiz: @quiz, question: @question)
  end
end
