# frozen_string_literal: true

# Closes quizzes nobody has answered for a day
class DeactivateStaleQuizzesJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    Quiz.where(active: true, updated_at: ...1.day.ago).update_all(active: false)
  end
end
