# frozen_string_literal: true

class QuestionsController < ApplicationController
  include QuestionAnswers

  before_action :authenticate_user!

  def index
    @subjects = policy_scope(Subject.authored_by(current_user, :question_author).where(active: true))
      .includes(:topics)
    raise Pundit::NotAuthorizedError if @subjects.blank?

    @question_counts = Question.where(topic: Topic.where(subject_id: @subjects.map(&:id), active: true))
      .group(:topic_id).count
  end

  def edit
    @question = authorize find_question
    assign_question_params(@question) if params[:question].present?
    check_answers(@question)
  end

  def update
    @question = authorize find_question
    assign_question_params(@question)
    check_answers(@question)

    if @question.save
      redirect_to edit_question_path(@question), notice: "Question successfully updated"
    else
      render :edit
    end
  end

  def destroy
    question = authorize find_question
    topic = question.topic
    question.update_attribute(:active, false)
    redirect_to topic_questions_path(topic)
  end

  private

  def question_params
    params.require(:question).permit(:question_text, :question_type, :lesson_id,
      :topic_id, answers_attributes: %i[correct id text _destroy])
  end

  def find_question
    Question.find(params[:id])
  end

  # Re-authorizes because the params can move the question to another topic
  def assign_question_params(question)
    question.assign_attributes(question_params)
    authorize question
  end
end
