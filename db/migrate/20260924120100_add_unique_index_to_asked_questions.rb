# frozen_string_literal: true

# Allows one attempt row per question per quiz, removing any duplicates the
# index would reject.
#
# Deliberately no if_not_exists: a failed concurrent build leaves an INVALID
# index behind, and a rerun must fail on it rather than skip it silently.
class AddUniqueIndexToAskedQuestions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute "SET lock_timeout TO '10s'"

    # Keeps one row per pair, preferring the one holding a verdict, then the
    # oldest: a row is removed when its pair has a row that ranks above it.
    execute <<~SQL
      DELETE FROM asked_questions duplicate
      USING asked_questions original
      WHERE duplicate.quiz_id = original.quiz_id
        AND duplicate.question_id = original.question_id
        AND (original.correct IS NOT NULL, -original.id)
          > (duplicate.correct IS NOT NULL, -duplicate.id)
    SQL

    add_index :asked_questions, %i[quiz_id question_id],
      unique: true, algorithm: :concurrently

    # Covered by the leading column of the composite index above.
    remove_index :asked_questions, :quiz_id, algorithm: :concurrently
  end

  # Removed duplicates stay removed.
  def down
    add_index :asked_questions, :quiz_id, algorithm: :concurrently
    remove_index :asked_questions, %i[quiz_id question_id], algorithm: :concurrently
  end
end
