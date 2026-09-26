# frozen_string_literal: true

# A topic, or one of its lessons, set for a class to complete by a due time
class Homework < ApplicationRecord
  belongs_to :classroom
  belongs_to :topic
  belongs_to :lesson, optional: true

  has_many :homework_progresses, dependent: :destroy
  has_many :users, through: :classroom

  validates :due_date, presence: true
  validates :required, presence: true
  validate :due_date_cannot_be_in_the_past
  validate :topic_in_class_subject
  validate :lesson_in_topic

  after_create -> { assign_to(users.where(role: :student).ids) }

  # Names the homework by what was set: a lesson, or else its whole topic
  def title
    lesson&.title || topic.name
  end

  # Sets this homework for the given pupils in one insert; a pupil who already has it keeps their row
  def assign_to(pupil_ids)
    rows = pupil_ids.map { |pupil_id| {homework_id: id, user_id: pupil_id, progress: 0, completed: false} }
    HomeworkProgress.insert_all(rows, unique_by: %i[homework_id user_id]) if rows.any?
  end

  # A pupil's state from their progress row, missing if they joined after this was set; each state needs
  # an entry in ClassroomsHelper::HOMEWORK_SLOTS and DashboardHelper::PUPIL_HOMEWORK_ICONS. Due times
  # are clock times stored as UTC, so in summer a completion up to an hour late reads as on time.
  def state_for(progress)
    return :not_set if progress.nil?
    return progress.completed_at.after?(due_date) ? :done_late : :done if progress.completed?

    due_date.past? ? :overdue : :not_due
  end

  private

  # The form offers only the class's subject's topics; one from another subject would score points there
  def topic_in_class_subject
    return if topic.nil? || classroom.nil? || topic.subject_id == classroom.subject_id

    errors.add(:topic, "isn't one of this class's topics")
  end

  # Quiz::CreateQuiz refuses a lesson outside the topic, so the homework could never be started
  def lesson_in_topic
    errors.add(:lesson_id, "isn't in the chosen topic") if lesson && lesson.topic_id != topic_id
  end

  def due_date_cannot_be_in_the_past
    errors.add(:due_date, "can't be in the past") if due_date.present? && due_date.past?
  end
end
