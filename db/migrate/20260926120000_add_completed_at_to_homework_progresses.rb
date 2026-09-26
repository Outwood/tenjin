# frozen_string_literal: true

# Records when a pupil completed a homework, so a completion after the due time shows as late.
class AddCompletedAtToHomeworkProgresses < ActiveRecord::Migration[7.2]
  # Progress is updated as each quiz finishes, so a completion happened when the first quiz on the
  # topic to reach the pass mark, finished after the homework was set, took its last answer
  QUIZ_BACKFILL = <<~SQL
    UPDATE homework_progresses
    SET completed_at = crossing.completed_at
    FROM (
      SELECT homework_progresses.id, MIN(COALESCE(quizzes.time_last_answered, quizzes.updated_at)) AS completed_at
      FROM homework_progresses
      JOIN homeworks ON homeworks.id = homework_progresses.homework_id
      JOIN quizzes ON quizzes.user_id = homework_progresses.user_id
        AND quizzes.topic_id = homeworks.topic_id
        AND NOT quizzes.active
        AND COALESCE(quizzes.time_last_answered, quizzes.updated_at) >= homeworks.created_at
        AND quizzes.answered_correct * 100 >= homeworks.required * quizzes.num_questions_asked
      WHERE homework_progresses.completed
      GROUP BY homework_progresses.id
    ) AS crossing
    WHERE homework_progresses.id = crossing.id
  SQL

  # A completion no quiz accounts for takes its last update, which a later score rise also moves
  UPDATED_AT_BACKFILL = <<~SQL
    UPDATE homework_progresses SET completed_at = updated_at WHERE completed AND completed_at IS NULL
  SQL

  def up
    execute "SET LOCAL lock_timeout TO '10s'"

    add_column :homework_progresses, :completed_at, :datetime
    execute QUIZ_BACKFILL
    execute UPDATED_AT_BACKFILL
  end

  def down
    execute "SET LOCAL lock_timeout TO '10s'"

    remove_column :homework_progresses, :completed_at
  end
end
