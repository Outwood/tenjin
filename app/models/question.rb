# frozen_string_literal: true

# A question in a topic, with the answers that define how it is marked
class Question < ApplicationRecord
  ANSWERS_REPEAT = "Answers must be different from each other"

  # Before answers, so deleting them has no attempts left to unlink
  has_many :asked_questions, dependent: :delete_all
  has_many :answers, dependent: :destroy
  has_many :flagged_questions, dependent: :destroy
  has_many :quizzes, through: :asked_questions
  has_one :question_statistic, dependent: :destroy

  belongs_to :lesson, optional: true, counter_cache: true
  belongs_to :topic

  has_rich_text :question_text

  enum :question_type, {short_answer: 0, boolean: 1, multiple: 2}, validate: true

  def self.counts_by_subject
    joins(topic: :subject).group("topics.subject_id").count
  end

  before_update :check_boolean
  before_save :note_answer_text_writes
  after_save :check_answer_texts_now
  before_update :check_short_answer

  accepts_nested_attributes_for :answers, allow_destroy: true

  validates :question_text, presence: true
  validates :active, inclusion: {in: [true, false]}
  validates_associated :answers

  validate :at_least_one_correct_answer
  validate :answers_distinct
  validate :boolean_true_or_false
  validate :lesson_is_for_topic

  def lesson_is_for_topic
    errors.add :base, "Lesson topic must match question topic" unless lesson.blank? || lesson.topic == topic
  end

  def boolean_true_or_false
    return unless boolean?

    answer_text = kept_answers.filter_map { |i| i&.text }
    # Check for the presence of both true and false in two answers in a case insensitive search
    return errors.add :base, "Boolean question must contain two answers" unless answer_text.size == 2

    labels = answer_text.map(&:downcase)
    return if labels.sort == %w[false true]
    return errors.add :base, "Boolean must be true or false only" unless labels.all? { |label| %w[true false].include?(label) }

    errors.add :base, "Boolean question must have one True and one False answer"
  end

  def answers_distinct
    keys = kept_answers.map { |answer| answer_key(answer.text.to_s) }.reject(&:empty?)
    errors.add :base, ANSWERS_REPEAT if keys.uniq.size < keys.size
  end

  def at_least_one_correct_answer
    return if kept_answers.any?(&:correct)

    errors.add :base, "Question must have at least one correct answer."
  end

  def as_json(*)
    json = {question_text: question_text.body,
            question_type: question_type,
            answers: answers.as_json(only: %i[text correct])}
    json[:lesson] = lesson.title if lesson
    json
  end

  private

  # Options show as typed, so case tells them apart; a short answer is
  # checked ignoring case, as Quiz::CheckAnswer compares it. A text written
  # around the model is stored as given, so it is normalised here too.
  def answer_key(text)
    key = Answer.normalize_value_for(:text, text)
    short_answer? ? key.downcase(:fold) : key
  end

  # The constraint waits for commit so a save can swap two options' texts.
  # Checking once every answer is written turns a repeat another save
  # committed first into the validation error, inside this save. A new
  # question's answers can only repeat each other, which validation catches. The
  # savepoint is rolled back either way, which keeps the caller's
  # transaction usable and its constraint mode as it was.
  def check_answer_texts_now
    return unless @writes_answer_text && !previously_new_record?

    self.class.transaction(requires_new: true) do
      self.class.connection.execute("SET CONSTRAINTS #{Answer::TEXT_CONSTRAINT} IMMEDIATE")
      raise ActiveRecord::Rollback
    end
  rescue ActiveRecord::RecordNotUnique => e
    raise unless answer_text_repeat?(e)

    errors.add :base, ANSWERS_REPEAT
    raise ActiveRecord::RecordInvalid, self
  end

  # Only answers already loaded can be written by this save
  def note_answer_text_writes
    @writes_answer_text = answers.target.any? do |answer|
      !answer.marked_for_destruction? && (answer.new_record? || answer.text_changed?)
    end
  end

  # The check fires for every row the transaction has pending, so the
  # violated key must be this question's before the repeat is claimed
  def answer_text_repeat?(error)
    return false unless error.cause.respond_to?(:result)

    result = error.cause.result
    result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == Answer::TEXT_CONSTRAINT &&
      result.error_field(PG::Result::PG_DIAG_MESSAGE_DETAIL).to_s[/\(question_id, text\)=\((\d+),/, 1] == id.to_s
  end

  # Answers removed through nested attributes stay loaded until the save
  def kept_answers
    answers.reject(&:marked_for_destruction?)
  end

  def check_boolean
    return unless question_type_changed? && boolean?

    answers.destroy_all
    Answer.create(question: self, correct: false, text: "False")
    Answer.create(question: self, correct: false, text: "True")
  end

  def check_short_answer
    return unless question_type_changed? && short_answer?

    answers.update_all(correct: true)
  end

  def plain_question_text
    question_text.to_plain_text
  end
end
