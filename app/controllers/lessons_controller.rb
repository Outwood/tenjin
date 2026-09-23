# frozen_string_literal: true

class LessonsController < ApplicationController
  before_action :authenticate_user!

  def index
    @author = current_user.has_role? :lesson_author, :any

    set_permitted_lessons_and_subjects

    @lessons_by_subject = @lessons.group_by { |lesson| lesson.topic.subject_id }
    # Authored subjects with no lessons yet still need a way to add the first
    @subjects = Subject.where(id: @lessons_by_subject.keys + @editable_subjects.to_a.map(&:id))
    # Active questions only: lessons.questions_count counts every question
    @active_question_counts = Question.where(lesson_id: @lessons.map(&:id), active: true)
      .group(:lesson_id).count
    @open_topic_id = Integer(params[:open], exception: false)
  end

  def new
    subject = Subject.find(params[:subject_id])
    @topics = topics_for(subject)
    return redirect_to lessons_path, flash: {error: "No topics found for subject"} if @topics.empty?

    @lesson = Lesson.new(topic: @topics.first)
    authorize @lesson
  end

  def edit
    @lesson = find_lesson
    @topics = topics_for(@lesson.subject)
    authorize @lesson
  end

  def create
    @lesson = Lesson.new(lesson_params)
    authorize @lesson
    save_lesson
  end

  def update
    @lesson = authorize find_lesson
    @lesson.assign_attributes(lesson_params)
    save_lesson
  end

  def destroy
    lesson = authorize find_lesson
    lesson.destroy
    redirect_to_topic(lesson.topic)
  end

  private

  def find_lesson
    Lesson.find(params[:id])
  end

  # One query for new, edit and the invalid re-render: TopicPolicy scopes by
  # question_author, a role a lesson author need not hold.
  def topics_for(subject)
    Topic.where(active: true, subject: subject).order(:name)
  end

  def save_lesson
    unless @lesson.valid?
      @topics = topics_for(@lesson.subject)

      return render :edit if @lesson.persisted?

      return render :new
    end

    @lesson.save!

    redirect_to_topic(@lesson.topic)
  end

  # The index starts with every topic closed, so reopen the one just changed
  def redirect_to_topic(topic)
    redirect_to lessons_path(open: topic.id)
  end

  def lesson_params
    params.require(:lesson).permit(:title, :video_link, :topic_id, :category)
  end

  def set_permitted_lessons_and_subjects
    if @author
      # Loaded so the index can check each subject against it without a query
      @editable_subjects = Subject.authored_by(current_user, :lesson_author).load
      @lessons = policy_scope(Lesson)
        .or(Lesson
                  .includes(:topic)
                  .where(topics: {subject: @editable_subjects.pluck(:id)})).order("topics.name, lessons.title")
    else
      @lessons = policy_scope(Lesson).includes(:topic).order("topics.name, lessons.title")
    end
  end
end
