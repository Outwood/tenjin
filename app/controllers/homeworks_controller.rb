# frozen_string_literal: true

# Sets homework for a class, and shows or deletes it
class HomeworksController < ApplicationController
  before_action :authenticate_user!

  def show
    @homework = authorize find_homework
    # The pupils in the class now, as the completion figure counts them; one who joined after
    # the homework was set has no progress row
    @pupils = User.joins(:enrollments).where(role: "student", enrollments: {classroom: @homework.classroom})
      .order(:surname, :forename)
    @progress = @homework.homework_progresses.where(user: @pupils).index_by(&:user_id)
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
    Lesson.where(topic: classroom.subject.topics).where(questions_count: Quiz::QUESTION_COUNT..)
  end
end
