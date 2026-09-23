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

  # Left join so homework set on a class with no pupils still counts, as 0 of 0
  def homework_counts
    h_count = HomeworkProgress.arel_table[:id].count

    Homework.select(:id, h_count, homework_count_completed.sum.as("completed_count"), :due_date, :topic_id)
      .left_joins(:homework_progresses)
      .group(:id)
      .where(classroom: self)
      .preload(:topic)
  end

  def homework_count_completed
    h_count_completed = Arel::Nodes::Case.new HomeworkProgress.arel_table[:completed]
    h_count_completed.when(true).then(1).else(0)
  end
end
