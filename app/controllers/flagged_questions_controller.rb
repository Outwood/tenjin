# frozen_string_literal: true

class FlaggedQuestionsController < ApplicationController
  before_action :authenticate_user!

  def create
    flagged_question = FlaggedQuestion.where(question_id: create_flagged_question_params[:question_id], user: current_user).first_or_initialize
    authorize flagged_question

    if flagged_question.persisted?
      take_flag_off(flagged_question)
    else
      put_flag_on(flagged_question)
    end
  end

  private

  def take_flag_off(flagged_question)
    if flagged_question.destroy
      head :ok
    else
      render json: {errors: ["Flag not removed"]}, status: :unprocessable_content
    end
  end

  def put_flag_on(flagged_question)
    if flagged_question.save
      head :ok
    else
      render json: {errors: flagged_question.errors.full_messages}, status: :unprocessable_content
    end
  end

  def create_flagged_question_params
    params.require(:flagged_question).permit(:question_id)
  end
end
