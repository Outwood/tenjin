# frozen_string_literal: true

class Enrollment < ApplicationRecord
  belongs_to :user
  # School#start_sync and .from_wonde write enrollments_count themselves, bypassing this callback
  belongs_to :classroom, counter_cache: true

  has_one :subject, through: :classroom

  validates :user, uniqueness: {scope: :classroom_id}

  scope :in_subject, ->(subject) { joins(:classroom).where(classrooms: {subject_id: subject}) }

  # Enrolls the users the sync has just saved from one class. start_sync has emptied the school's
  # enrollments, so the rows go in with one insert; the count is then read back rather than taken
  # from the insert, which reports nothing for a row already present.
  def self.enroll(classroom, user_ids)
    rows = user_ids.uniq.map { |user_id| {classroom_id: classroom.id, user_id: user_id} }
    insert_all(rows, unique_by: %i[classroom_id user_id]) if rows.any?
    count = where(classroom: classroom).count
    classroom.update_columns(enrollments_count: count, disabled: count.zero?)
  end
end
