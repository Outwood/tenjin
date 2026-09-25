# frozen_string_literal: true

module QuestionsHelper
  def flag_icon
    if @flagged_question.present? && @flagged_question.persisted?
      "<i class='fas fa-flag' style='color: red'></i>".html_safe
    else
      "<i class='far fa-flag' style='color: red'></i>".html_safe
    end
  end

  # Leaves out the bare "Answers is invalid", which each answer's own error says better
  def question_error_messages(question)
    question.errors.reject { |error| error.attribute == :answers }.map(&:full_message).uniq
  end

  # A new question is created in the topic it was started from
  def question_form_url(question)
    question.persisted? ? question_path(question) : topic_questions_path(question.topic)
  end

  def percentage_correct(question)
    qs = question.question_statistic
    return "0%" if qs.blank?
    return "0%" if qs.number_asked.zero?

    number_to_percentage((qs.number_correct.to_f / qs.number_asked) * 100, precision: 0)
  end

  def times_asked(question)
    question.question_statistic&.number_asked || 0
  end
end
