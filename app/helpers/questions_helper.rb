# frozen_string_literal: true

module QuestionsHelper
  # One label per Question.question_types value
  QUESTION_TYPE_LABELS = {"short_answer" => "Short answer", "boolean" => "True or false", "multiple" => "Multiple choice"}.freeze

  def flag_icon
    if @flagged_question.present? && @flagged_question.persisted?
      "<i class='fas fa-flag' style='color: red'></i>".html_safe
    else
      "<i class='far fa-flag' style='color: red'></i>".html_safe
    end
  end

  # The label of a boolean question's one correct answer; none while that is in doubt
  def chosen_boolean_label(question)
    correct = question.answers.reject(&:marked_for_destruction?).select(&:correct)
    correct.first.text if correct.one?
  end

  # True before False, as a quiz offers them; other answers in the order they were written
  def listed_answers(question)
    return question.answers.sort_by { |answer| answer.text.downcase }.reverse if question.boolean?

    question.answers.sort_by(&:id)
  end

  # Whether the answer table has a Correct column, in its header and in every row
  def marks_correct_answers?(question)
    question.question_type.present? && !question.short_answer?
  end

  # Leaves out the bare "Answers is invalid", which each answer's own error says better
  def question_error_messages(question)
    question.errors.reject { |error| error.attribute == :answers }.map(&:full_message).uniq
  end

  # A new question is created in the topic it was started from
  def question_form_url(question)
    question.persisted? ? question_path(question) : topic_questions_path(question.topic)
  end

  # A question nobody has answered has no score, which "0%" would misreport as all wrong
  def percentage_correct(question)
    asked = times_asked(question)
    return "Not asked yet" if asked.zero?

    number_to_percentage(question.question_statistic.number_correct.to_f / asked * 100, precision: 0)
  end

  def question_type_label(question)
    QUESTION_TYPE_LABELS.fetch(question.question_type)
  end

  def times_asked(question)
    question.question_statistic&.number_asked || 0
  end
end
