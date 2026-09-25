# frozen_string_literal: true

class Homework::UpdateHomeworkProgress < ApplicationCommand
  def initialize(quiz:)
    @quiz = quiz
  end

  def call
    @completed_homework = false
    @save_errors = []

    homework_progresses.find_each do |progress|
      check_percentage_correct(progress)
    end

    return failure(@save_errors.join("; "), payload: {completed: @completed_homework}) if @save_errors.any?

    success(completed: @completed_homework)
  end

  private

  def homework_progresses
    HomeworkProgress.joins(:homework)
      .includes(:homework)
      .where(user: @quiz.user, homework: {topic_id: @quiz.topic})
  end

  def check_percentage_correct(progress)
    check_progress_percentage(@quiz.answered_correct.to_f / @quiz.num_questions_asked, progress)
  end

  def check_progress_percentage(percentage, progress)
    percentage *= 100
    progress.progress = percentage if percentage > progress.progress
    if progress.progress >= progress.homework.required && !progress.completed
      progress.completed = true
      progress.completed_at = Time.current
      @completed_homework = true
    end
    return unless progress.changed?

    @save_errors << progress.errors.full_messages.join(", ") unless progress.save
  end
end
