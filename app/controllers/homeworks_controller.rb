# frozen_string_literal: true

class HomeworksController < ApplicationController
  before_action :authenticate_user!

  def show
    @homework = authorize find_homework
    # Matches the class's completion figure, which leaves out pupils who have left or moved class
    @homework_progress = HomeworkProgress.includes(:user)
      .where(homework: @homework, user_id: @homework.classroom.enrollments.select(:user_id))
      .order("users.surname", "users.forename")
    @homework_counts = @homework.classroom.homework_counts.find_by(id: @homework)
  end

  def new
    @classroom = find_classroom
    @homework = authorize @classroom.homeworks.new(due_date: 1.week.from_now, required: 70)
    @lessons = lessons_for_classroom(@classroom)
  end

  def create
    @classroom = find_classroom
    @homework = authorize @classroom.homeworks.new(homework_params)
    if @homework.save
      flash[:notice] = "#{@homework.title} homework set"
      redirect_to @homework
    else
      @lessons = lessons_for_classroom(@classroom)
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    homework = authorize find_homework
    classroom = homework.classroom
    homework.destroy
    redirect_to classroom_path(classroom), notice: "#{homework.title} homework deleted", status: :see_other
  end

  private

  def find_classroom
    Classroom.find(params[:classroom_id])
  end

  def find_homework
    Homework.find(params[:id])
  end

  def homework_params
    params.require(:homework).permit(:due_date, :required, :topic_id, :lesson_id)
  end

  def lessons_for_classroom(classroom)
    Lesson.where(topic: classroom.subject.topics).where(questions_count: 10..)
  end
end
