# frozen_string_literal: true

module Lessons
  # A lesson's questions with their answers, for staff reviewing it.
  class QuestionsController < ApplicationController
    before_action :authenticate_user!

    def index
      @lesson = authorize Lesson.find(params[:lesson_id]), :view_questions?
      # Lesson viewers need not author questions, so the question scope does not apply
      skip_policy_scope
      @questions = Question.with_rich_text_question_text_and_embeds
        .includes(:answers)
        .where(lesson: @lesson, active: true)
    end
  end
end
