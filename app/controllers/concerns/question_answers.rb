# frozen_string_literal: true

# Shapes a question's answers to its type before the editor shows or saves them
module QuestionAnswers
  BOOLEAN_LABELS = %w[False True].freeze

  private

  def check_answers(question)
    setup_boolean_question(question) if question.boolean?
    question.answers.each { |a| a.correct = true } if question.short_answer? || question.question_type.nil?
  end

  def setup_boolean_question(question)
    question.answers.build until question.answers.length >= 2
    answers = question.answers.to_a
    kept = boolean_answers_to_keep(answers)
    # Marked, not removed: replacing the association deletes them at once, even on a preview
    (answers - kept).each(&:mark_for_destruction)
    label_boolean_answers(kept)
    # Puts any remaining errors in front of the author in the editor
    question.valid?
  end

  # The oldest answer meaning each label, then the rest oldest first; load
  # order is no guide, as Postgres moves rows it updates
  def boolean_answers_to_keep(answers)
    saved, unsaved = answers.partition(&:persisted?)
    by_age = saved.sort_by(&:id) + unsaved
    by_label = BOOLEAN_LABELS.filter_map { |label| by_age.find { |answer| boolean_label(answer) == label } }
    (by_label + (by_age - by_label)).first(2)
  end

  def boolean_label(answer)
    BOOLEAN_LABELS.find { |label| label.casecmp?(answer.text.to_s.strip) }
  end

  # Labels by meaning, so each answer keeps its correct flag; only answers
  # with no True/False meaning are labelled by position
  def label_boolean_answers(answers)
    labels = answers.map { |answer| boolean_label(answer) }
    labels = labels.map { nil } if labels.compact.uniq.size < labels.compact.size
    unused = BOOLEAN_LABELS - labels
    answers.zip(labels).each { |answer, label| answer.text = label || unused.shift }
  end
end
