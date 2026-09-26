# frozen_string_literal: true

# Stores a usage statistic's day as a date on UK clocks, with one row per pupil, topic, lesson and day, so two
# quizzes starting at once add to the same row.
class ChangeUsageStatisticsDateToDate < ActiveRecord::Migration[7.2]
  def up
    execute "SET LOCAL lock_timeout TO '10s'"

    # Rows hold UTC midnight, if saved before the app ran on UK time, or UK midnight; both fall on the UK day
    change_column :usage_statistics, :date, :date,
      using: "(date AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/London')::date"
    add_index :usage_statistics, %i[user_id topic_id lesson_id date],
      unique: true, nulls_not_distinct: true, name: "index_usage_statistics_on_pupil_and_day"
    # The unique index leads with user_id, so it serves every lookup this one did
    remove_index :usage_statistics, :user_id
  end

  def down
    execute "SET LOCAL lock_timeout TO '10s'"

    add_index :usage_statistics, :user_id
    remove_index :usage_statistics, name: "index_usage_statistics_on_pupil_and_day"
    change_column :usage_statistics, :date, :datetime, precision: nil, using: "date::timestamp"
  end
end
