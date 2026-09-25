# frozen_string_literal: true

class ClassroomsController < ApplicationController
  # The homework each pupil's strip shows, the latest due
  RECENT_HOMEWORK = 5

  before_action :authenticate_user!

  def index
    authorize current_user.school, :sync?
    @classrooms = policy_scope(Classroom).order(:name)
    @school = current_user.school
    @subjects = Subject.where(active: true)
  end

  def show
    @classroom = find_classroom
    authorize @classroom
    @students = User.joins(enrollments: :classroom).where(role: "student", enrollments: {classroom: @classroom})
      .order(:surname, :forename)
    @homeworks = @classroom.homework_counts.preload(:lesson)

    # Taken from the table's homeworks, whose topics are already loaded
    @recent_homeworks = @homeworks.sort_by { |h| [h.due_date, h.id] }.last(RECENT_HOMEWORK)
    @recent_progress = HomeworkProgress.where(homework_id: @recent_homeworks.map(&:id))
      .group_by(&:user_id).transform_values { |rows| rows.index_by(&:homework_id) }
  end

  def update
    classroom = authorize find_classroom

    unless classroom.update(subject_id: update_classroom_params[:subject])
      return refuse("Subject not changed: #{classroom.errors.full_messages.to_sentence}")
    end

    school = classroom.school
    unless school.update(sync_status: "needed")
      return refuse("Subject changed, but the school is not marked for a sync: #{school.errors.full_messages.to_sentence}")
    end

    head :no_content
  end

  private

  def find_classroom
    Classroom.find(params[:id])
  end

  def update_classroom_params
    params.permit(:subject, :id)
  end
end
