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
      check_answer_correct unless already_answered?

      Quiz::MoveQuizForward.call(quiz: @quiz)
      @quiz.save!
    end

    success(Quiz::CheckAnswerOutcome.new(
      question: @question,
      correct: @asked_question.correct,
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

  def already_answered?
    !@asked_question.correct.nil?
  end

  def check_answer_correct
    @question.short_answer? ? check_short_answer : check_multiple_choice
  end

  def check_short_answer
    accepted = Answer.where(question_id: @question, correct: true).pluck(:text)
    return if accepted.empty?

    guess = normalise(@answer_given[:short_answer])
    if accepted.any? { |text| guess.casecmp?(normalise(text)) }
      process_correct_answer
    else
      process_incorrect_answer
    end
  end

  # Stray spacing is never what separates a right answer from a wrong one
  def normalise(text)
    text.to_s.strip.gsub(/\s+/, " ")
  end

  def check_multiple_choice
    chosen_answer.correct ? process_correct_answer : process_incorrect_answer
  end

  def process_correct_answer
    @quiz.answered_correct += 1
    @quiz.streak += 1
    @asked_question.update_attribute(:correct, true)
    Quiz::AddLeaderboardPoint.call(quiz: @quiz, question: @question)
  end

  def process_incorrect_answer
    @quiz.streak = 0
    @asked_question.update_attribute(:correct, false)
  end
end
