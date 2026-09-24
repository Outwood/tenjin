# frozen_string_literal: true

# Refuses two answers on one question that a student could not tell apart:
# the same text once edge whitespace is trimmed and inner runs collapsed.
# Case is kept, because options render as typed and string-manipulation
# questions offer case variants on purpose; the short-answer case rule lives
# in Question's validation, since the constraint cannot see the type.
#
# The key is a stored generated column so the constraint can be DEFERRABLE:
# an editor save that swaps two options' texts passes through a moment where
# both rows hold the same text, and only the committed state must be unique.
#
# Deliberately no if_not_exists: a failed concurrent build leaves an INVALID
# index behind, and a rerun must fail on it rather than skip it silently.
class AddUniqueAnswerTextPerQuestion < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # Answer.normalise_text in SQL; the class is Ruby's \s, not Postgres's
  TEXT_KEY = "btrim(regexp_replace(text, '[ \\t\\n\\r\\f\\v]+', ' ', 'g'))"
  INDEX = "answers_question_id_text_key"

  def up
    execute "SET lock_timeout TO '10s'"

    add_column :answers, :text_key, :virtual, type: :string, as: TEXT_KEY, stored: true
    add_index :answers, %i[question_id text_key], unique: true, name: INDEX, algorithm: :concurrently
    add_unique_constraint :answers, using_index: INDEX, name: INDEX, deferrable: :deferred

    # Covered by the leading column of the unique index above.
    remove_index :answers, :question_id, algorithm: :concurrently
  end

  def down
    add_index :answers, :question_id, algorithm: :concurrently
    remove_unique_constraint :answers, name: INDEX
    remove_column :answers, :text_key
  end
end
