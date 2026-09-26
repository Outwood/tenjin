# frozen_string_literal: true

# A pupil's count of quizzes started on one topic or lesson in one day
class UsageStatistic < ApplicationRecord
  belongs_to :user
  belongs_to :topic, optional: true
  belongs_to :lesson, optional: true

  # date is a datetime column, which a Date would match only at UTC midnight
  scope :on_day_of, ->(time) { where(date: time.all_day) }
end
