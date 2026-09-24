# frozen_string_literal: true

# Collapses the whitespace in stored answer texts and makes each text unique within its question
#
# Every step is idempotent so a rerun after a failure resumes cleanly.
class AddUniqueAnswerTextPerQuestion < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # ActiveSupport's String#squish, which Answer applies on write: the class is
  # every code point Ruby's [[:space:]] matches.
  SQUISHED_TEXT = "btrim(regexp_replace(text, " \
    "'[\\t\\n\\v\\f\\r \\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000]+', " \
    "' ', 'g'), ' ')"

  # Answer::TEXT_CONSTRAINT. Case is kept: options render as typed, and
  # string-manipulation questions offer case variants on purpose; the
  # short-answer case rule lives in Question's validation, since the
  # constraint cannot see the type.
  INDEX = "answers_question_id_text"

  # Question.question_types["short_answer"]
  SHORT_ANSWER = 0

  def up
    refuse_colliding_answers

    execute "SET lock_timeout TO '10s'"
    execute "UPDATE answers SET text = #{SQUISHED_TEXT} WHERE text <> #{SQUISHED_TEXT}"

    unless unique_constraint?
      build_unique_index
      # Deferred because an editor save that swaps two options' texts passes
      # through a moment where both rows hold the same text
      add_unique_constraint :answers, using_index: INDEX, name: INDEX, deferrable: :deferred
    end

    # Covered by the leading column of the unique constraint above.
    remove_index :answers, :question_id, algorithm: :concurrently, if_exists: true
  ensure
    execute "RESET lock_timeout"
  end

  # Texts stay normalised.
  def down
    add_index :answers, :question_id, algorithm: :concurrently, if_not_exists: true
    execute "SET lock_timeout TO '10s'"
    remove_unique_constraint :answers, name: INDEX if unique_constraint?
    # An up that failed between building the index and attaching it
    remove_index :answers, name: INDEX, algorithm: :concurrently, if_exists: true
  ensure
    execute "RESET lock_timeout"
  end

  private

  # Deleting either copy is a judgement about which one is right, so it is
  # left to a person; the texts are untouched when this refuses. Short
  # answers that differ only in case are refused too: the constraint would
  # take them, but Question's validation would then refuse every later save
  # of the question. The keys are built in Ruby, as Question builds them,
  # because Postgres's lower() folds case differently ("Straße").
  def refuse_colliding_answers
    rows = select_rows(<<~SQL)
      SELECT answers.id, answers.question_id, questions.question_type, answers.text
      FROM answers JOIN questions ON questions.id = answers.question_id
      WHERE answers.text IS NOT NULL
    SQL
    groups = rows.group_by do |_id, question, type, text|
      key = text.squish
      [question, (type.to_i == SHORT_ANSWER) ? key.downcase(:fold) : key]
    end
    collisions = groups.select { |_key, answers| answers.size > 1 }.sort_by { |(question, _), _| question.to_i }
    return if collisions.empty?

    raise "Answers that repeat once their whitespace is collapsed, or for a short answer their case ignored: " +
      collisions.map { |(question, _), answers| "question #{question} (answers #{answers.map(&:first).join(", ")})" }.join("; ")
  end

  # A failed concurrent build leaves an INVALID index behind; it is rebuilt,
  # never taken as done. The build waits out long transactions rather than
  # timing out on them, since it blocks no writes while it waits.
  def build_unique_index
    remove_index :answers, name: INDEX, algorithm: :concurrently if invalid_index?
    return if index_exists?(:answers, %i[question_id text], name: INDEX)

    execute "RESET lock_timeout"
    add_index :answers, %i[question_id text], unique: true, name: INDEX, algorithm: :concurrently
    execute "SET lock_timeout TO '10s'"
  end

  def unique_constraint?
    unique_constraints(:answers).any? { |constraint| constraint.name == INDEX }
  end

  def invalid_index?
    select_value(<<~SQL).present?
      SELECT 1 FROM pg_index JOIN pg_class ON pg_class.oid = pg_index.indexrelid
      WHERE pg_class.relname = #{connection.quote(INDEX)} AND NOT pg_index.indisvalid
    SQL
  end
end
