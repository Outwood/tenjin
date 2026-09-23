# frozen_string_literal: true

# Allows one flag per student per question and one unlock per user per
# customisation, removing any duplicates the indexes would reject.
#
# Deliberately no if_not_exists: a failed concurrent build leaves an INVALID
# index behind, and a rerun must fail on it rather than skip it silently.
class AddUniqueIndexesToFlagsAndUnlocks < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute "SET lock_timeout TO '10s'"

    # One statement, so the counter drops with the rows it counts. Every CTE
    # reads the pre-delete snapshot, hence a decrement rather than a recount.
    execute <<~SQL
      WITH removed AS (
        DELETE FROM flagged_questions duplicate
        USING flagged_questions original
        WHERE duplicate.question_id = original.question_id
          AND duplicate.user_id = original.user_id
          AND duplicate.id > original.id
        RETURNING duplicate.question_id
      )
      UPDATE questions
      SET flagged_questions_count = flagged_questions_count - removed.count
      FROM (SELECT question_id, count(*) AS count FROM removed GROUP BY question_id) removed
      WHERE questions.id = removed.question_id
    SQL

    execute <<~SQL
      DELETE FROM customisation_unlocks duplicate
      USING customisation_unlocks original
      WHERE duplicate.user_id = original.user_id
        AND duplicate.customisation_id = original.customisation_id
        AND duplicate.id > original.id
    SQL

    add_index :flagged_questions, %i[question_id user_id],
      unique: true, algorithm: :concurrently
    add_index :customisation_unlocks, %i[user_id customisation_id],
      unique: true, algorithm: :concurrently

    # Covered by the leading column of the composite indexes above.
    remove_index :flagged_questions, :question_id, algorithm: :concurrently
    remove_index :customisation_unlocks, :user_id, algorithm: :concurrently
  end

  # Removed duplicates stay removed.
  def down
    add_index :customisation_unlocks, :user_id, algorithm: :concurrently
    add_index :flagged_questions, :question_id, algorithm: :concurrently
    remove_index :customisation_unlocks, %i[user_id customisation_id], algorithm: :concurrently
    remove_index :flagged_questions, %i[question_id user_id], algorithm: :concurrently
  end
end
