# frozen_string_literal: true

# A pupil's count of quizzes started on one topic or lesson in one day
class UsageStatistic < ApplicationRecord
  belongs_to :user
  belongs_to :topic, optional: true
  belongs_to :lesson, optional: true

  # Counts a quiz start today in one statement, so two quizzes starting at once add to the same row
  def self.count_start(user_id:, topic_id:, lesson_id:)
    upsert({user_id:, topic_id:, lesson_id:, date: Date.current, quizzes_started: 1},
      unique_by: :index_usage_statistics_on_pupil_and_day,
      on_duplicate: Arel.sql("quizzes_started = usage_statistics.quizzes_started + 1, updated_at = EXCLUDED.updated_at"))
  end
end
