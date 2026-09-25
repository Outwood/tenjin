# frozen_string_literal: true

# When a pupil completed a homework, so a completion after the due time can be told apart.
# Rows completed before the column existed keep NULL and read as on time.
class AddCompletedAtToHomeworkProgresses < ActiveRecord::Migration[7.2]
  def change
    add_column :homework_progresses, :completed_at, :datetime
  end
end
