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
      .where(user: @quiz.user, homework: {topic_id: @quiz.topic})
  end

  def check_percentage_correct(progress)
    check_progress_percentage(@quiz.answered_correct.to_f / @quiz.num_questions_asked, progress)
  end

  # The row lock reloads the row, so of two quizzes finishing together the second sees the
  # first's score and completion, and the first completion keeps its time
  def check_progress_percentage(percentage, progress)
    progress.with_lock do
      percentage *= 100
      progress.progress = percentage if percentage > progress.progress
      if progress.progress >= progress.homework.required && !progress.completed?
        progress.completed = true # kept in step with completed_at until the column is dropped
        progress.completed_at = Time.current
        @completed_homework = true
      end
      next unless progress.changed?

      @save_errors << progress.errors.full_messages.join(", ") unless progress.save
    end
  end
end
