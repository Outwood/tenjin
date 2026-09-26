# frozen_string_literal: true

# One progress row per pupil per homework, so setting a homework again for a pupil leaves theirs alone.
class AddUniquePupilIndexToHomeworkProgresses < ActiveRecord::Migration[7.2]
  def up
    execute "SET LOCAL lock_timeout TO '10s'"

    add_index :homework_progresses, %i[homework_id user_id], unique: true
    # The unique index leads with homework_id, so it serves every lookup this one did
    remove_index :homework_progresses, :homework_id
  end

  def down
    execute "SET LOCAL lock_timeout TO '10s'"

    add_index :homework_progresses, :homework_id
    remove_index :homework_progresses, %i[homework_id user_id]
  end
end
