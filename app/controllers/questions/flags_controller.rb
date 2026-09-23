# frozen_string_literal: true

module Questions
  # The signed-in student's flag marking a question as unfair.
  class FlagsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_flag

    def create
      return head :ok if @flag.persisted?

      if @flag.save
        head :ok
      else
        render json: {errors: @flag.errors.full_messages}, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      # A concurrent request saved this student's flag first
      head :ok
    end

    def destroy
      return head :ok unless @flag.persisted?

      if @flag.destroy
        head :ok
      else
        render json: {errors: ["Flag not removed"]}, status: :unprocessable_content
      end
    end

    private

    def set_flag
      question = Question.find(params[:question_id])
      @flag = authorize FlaggedQuestion.find_or_initialize_by(question: question, user: current_user)
    end
  end
end
