# frozen_string_literal: true

# A pupil's best score on a homework, and when they reached its pass mark
class HomeworkProgress < ApplicationRecord
  belongs_to :homework
  belongs_to :user

  has_one :topic, through: :homework

  # Completion is read from completed_at; the completed column is kept in step for a rollback, and
  # no app code reads it
  def completed? = completed_at.present?
end
