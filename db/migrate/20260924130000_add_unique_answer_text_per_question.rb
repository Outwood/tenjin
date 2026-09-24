# frozen_string_literal: true

# Stores every answer's text with its whitespace collapsed, as Answer now
# normalises it on write, and refuses two answers on one question with the
# same text. Case is kept: options render as typed, and string-manipulation
# questions offer case variants on purpose; the short-answer case rule lives
# in Question's validation, since the constraint cannot see the type.
#
# The constraint is DEFERRABLE because an editor save that swaps two
# options' texts passes through a moment where both rows hold the same text.
#
# Every step is idempotent so a rerun after a failure resumes cleanly.
class AddUniqueAnswerTextPerQuestion < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # ActiveSupport's String#squish: the class is every code point Ruby's
  # [[:space:]] matches.
  SQUISHED_TEXT = "btrim(regexp_replace(text, " \
    "'[\\t\\n\\v\\f\\r \\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000]+', " \
    "' ', 'g'), ' ')"
  INDEX = "answers_question_id_text"

  def up
    execute "SET lock_timeout TO '10s'"
    execute "UPDATE answers SET text = #{SQUISHED_TEXT} WHERE text <> #{SQUISHED_TEXT}"

    unless unique_constraint?
      build_unique_index
      add_unique_constraint :answers, using_index: INDEX, name: INDEX, deferrable: :deferred
    end

    # Covered by the leading column of the unique constraint above.
    remove_index :answers, :question_id, algorithm: :concurrently, if_exists: true
  end

  # Texts stay normalised.
  def down
    add_index :answers, :question_id, algorithm: :concurrently, if_not_exists: true
    remove_unique_constraint :answers, name: INDEX if unique_constraint?
  end

  private

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
