# frozen_string_literal: true

# Judges a pupil's answer to the quiz's current question, records it and scores it
class Quiz::CheckAnswer < ApplicationCommand
  # Far above the longest accepted text; bounds what an attempt row stores
  MAX_RESPONSE_LENGTH = 1000

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
        # Last, so the statistics row other pupils share stays locked only until commit
        Quiz::CountAnswer.call(question_id: @question.id, user_id: @quiz.user_id, correct: @correct,
          answered_at: @answered_at)
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

  # Only one of the question's own answers counts, and only typed text the attempt row can store
  def no_answer?
    return !storable?(typed_answer) if @question.short_answer?

    chosen_answer.nil?
  end

  # Postgres cannot hold NUL in jsonb
  def storable?(text)
    text.length <= MAX_RESPONSE_LENGTH && !text.include?("\u0000")
  end

  def typed_answer
    @answer_given[:short_answer].to_s
  end

  def chosen_answer
    return if @question.short_answer?

    @chosen_answer ||= @question.answers.find_by(id: @answer_given[:id])
  end

  # Records the answer only while the question is unanswered. A parallel
  # submission's write holds the row until it commits, so exactly one of them scores.
  def claim_question
    @correct = verdict
    @answered_at = Time.current

    # A row answered before answered_at existed carries only its verdict
    AskedQuestion.where(id: @asked_question.id, answered_at: nil, correct: nil)
      .update_all(correct: @correct, answer_id: chosen_answer&.id, response: {text: response_text},
        answered_at: @answered_at, updated_at: @answered_at) == 1
  end

  # The text as the pupil saw it, which outlives the option being reworded or deleted
  def response_text
    @question.short_answer? ? typed_answer : chosen_answer.text
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

    guess = Answer.normalize_value_for(:text, typed_answer)
    # A text written around the model is stored as given
    accepted.any? { |text| guess.casecmp?(Answer.normalize_value_for(:text, text)) }
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
