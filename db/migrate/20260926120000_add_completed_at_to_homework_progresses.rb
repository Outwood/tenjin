# frozen_string_literal: true

# Records when a pupil completed a homework, so a completion after the due time shows as late.
class AddCompletedAtToHomeworkProgresses < ActiveRecord::Migration[7.2]
  # Progress is updated when a quiz finishes, its last write, so a completion is dated by the first quiz
  # on the topic to finish at the pass mark after the homework was set. A quiz closed early, abandoned
  # or replaced, has not asked every question it started with, so does not count.
  QUIZ_BACKFILL = <<~SQL
    UPDATE homework_progresses
    SET completed_at = crossing.completed_at
    FROM (
      SELECT homework_progresses.id, MIN(quizzes.updated_at) AS completed_at
      FROM homework_progresses
      JOIN homeworks ON homeworks.id = homework_progresses.homework_id
      JOIN quizzes ON quizzes.user_id = homework_progresses.user_id
        AND quizzes.topic_id = homeworks.topic_id
        AND quizzes.num_questions_asked > 0
        AND quizzes.num_questions_asked >= (SELECT COUNT(*) FROM asked_questions WHERE asked_questions.quiz_id = quizzes.id)
        AND quizzes.updated_at >= homeworks.created_at
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
