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
    @homework = authorize @classroom.homeworks.new(due_date: default_due_date, required: 70)
    load_choices
  end

  def create
    @classroom = find_classroom
    @homework = authorize @classroom.homeworks.new(homework_params)
    if @homework.save
      flash[:notice] = "#{@homework.title} homework set"
      redirect_to @homework
    else
      load_choices
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

  # A week on, to the nearest five minutes: the date picker steps minutes in fives
  def default_due_date
    step = 5.minutes.to_i
    Time.zone.at((1.week.from_now.to_f / step).round * step)
  end

  def homework_params
    params.require(:homework).permit(:due_date, :required, :topic_id, :lesson_id)
  end

  # What a homework quiz can be built from: Quiz::CreateQuiz asks only active questions, so a topic
  # needs one and a lesson a quiz's worth. An inactive topic stays on offer to teachers.
  def load_choices
    active_questions = Question.where(active: true)
    @topics = @classroom.subject.topics.where(id: active_questions.select(:topic_id)).order(:name)
    @lessons = Lesson.where(topic: @topics).where(id: active_questions.group(:lesson_id)
      .having("COUNT(*) >= ?", Quiz::QUESTION_COUNT).select(:lesson_id))
  end
end
