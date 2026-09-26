# frozen_string_literal: true

class Homework < ApplicationRecord
  belongs_to :classroom
  belongs_to :topic
  belongs_to :lesson, optional: true

  has_many :homework_progresses, dependent: :destroy
  has_many :users, through: :classroom

  validates :due_date, presence: true
  validates :topic, presence: true
  validates :required, presence: true
  validate :due_date_cannot_be_in_the_past

  after_create :create_homework_progresses

  # Names the homework by what was set: a lesson, or else its whole topic
  def title
    lesson&.title || topic.name
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

  def due_date_cannot_be_in_the_past
    errors.add(:due_date, "can't be in the past") if due_date.present? && due_date.past?
  end

  def create_homework_progresses
    users.where(role: :student).find_each do |u|
      homework_progresses.create(user: u, progress: 0, completed: false)
    end
  end
end
