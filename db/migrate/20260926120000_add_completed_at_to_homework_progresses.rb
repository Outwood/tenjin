# frozen_string_literal: true

# Records when a pupil completed a homework, so a completion after the due time shows as late.
class AddCompletedAtToHomeworkProgresses < ActiveRecord::Migration[7.2]
  def up
    execute "SET LOCAL lock_timeout TO '10s'"

    add_column :homework_progresses, :completed_at, :datetime

    # The nearest time known for an existing completion; a later score rise also moves updated_at,
    # so a pupil who kept practising after the due time reads as late
    execute "UPDATE homework_progresses SET completed_at = updated_at WHERE completed"
  end

  def down
    execute "SET LOCAL lock_timeout TO '10s'"

    remove_column :homework_progresses, :completed_at
  end
end
