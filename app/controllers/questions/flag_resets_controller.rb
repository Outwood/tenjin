# frozen_string_literal: true

module Questions
  # Clears every student's flag on a question, for its author.
  class FlagResetsController < ApplicationController
    before_action :authenticate_user!

    def create
      question = authorize Question.find(params[:question_id]), :update?
      FlaggedQuestion.where(question: question).delete_all
      Question.reset_counters question.id, :flagged_questions_count
      redirect_to edit_question_path(question)
    end
  end
end
