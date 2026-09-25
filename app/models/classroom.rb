# frozen_string_literal: true

class Classroom < ApplicationRecord
  belongs_to :subject, optional: true
  belongs_to :school
  has_many :enrollments
  has_many :users, through: :enrollments
  has_many :homeworks

  validates :client_id, presence: true, uniqueness: true
  validates :name, presence: true

  def self.from_wonde(school, wonde_class)
    c = where(client_id: wonde_class["id"]).first_or_initialize
    c.client_id = wonde_class["id"]
    c.name = wonde_class["name"]
    c.description = wonde_class["description"]
    c.code = wonde_class["code"]
    c.school_id = school.id
    c.disabled = false
    c.save!
    c
  end

  # Counts only the pupils in the class now: one who leaves or moves class keeps their progress rows
  def homework_counts
    h_count = HomeworkProgress.arel_table[:id].count

    Homework.select(:id, h_count, homework_count_completed.sum.as("completed_count"), :due_date, :topic_id, :lesson_id)
      .joins(current_pupil_progress_join)
      .group(:id)
      .where(classroom: self)
      .preload(:topic)
  end

  private

  # Left join, with the enrolment test in its condition, so homework set on a class
  # with no pupils still counts, as 0 of 0
  def current_pupil_progress_join
    homeworks = Homework.arel_table
    progresses = HomeworkProgress.arel_table
    current_pupils = enrollments.select(:user_id).arel

    homeworks.join(progresses, Arel::Nodes::OuterJoin)
      .on(progresses[:homework_id].eq(homeworks[:id]).and(progresses[:user_id].in(current_pupils)))
      .join_sources
  end

  def homework_count_completed
    h_count_completed = Arel::Nodes::Case.new HomeworkProgress.arel_table[:completed]
    h_count_completed.when(true).then(1).else(0)
  end
end
