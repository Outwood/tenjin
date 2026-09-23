# frozen_string_literal: true

module Topics
  # A topic's question bank: its list, its JSON export, and new questions for it.
  class QuestionsController < ApplicationController
    include QuestionAnswers

    before_action :authenticate_user!
    before_action :set_topic

    def index
      authorize @topic, :show?
      # The authorized topic bounds the list, inactive topics included
      skip_policy_scope

      respond_to do |format|
        format.html do
          @questions = Question.with_rich_text_question_text_and_embeds
            .includes(:question_statistic, :lesson)
            .where(topic: @topic, active: true)
        end
        format.json do
          send_data Question.where(topic: @topic).to_json(include: :answers),
            type: "application/json; header=present",
            disposition: "attachment; filename=#{@topic.name}.json"
        end
      end
    end

    def new
      @question = authorize @topic.questions.new(question_params)
      check_answers(@question)
    end

    def create
      @question = authorize @topic.questions.new(question_params)
      check_answers(@question)

      if @question.save
        redirect_to topic_questions_path(@topic), notice: "Question successfully created"
      else
        render :new
      end
    end

    private

    def set_topic
      @topic = Topic.find(params[:topic_id])
    end

    # The topic comes from the path; a question moves topic only once saved
    def question_params
      params.fetch(:question, {}).permit(:question_text, :question_type, :lesson_id,
        answers_attributes: %i[correct id text _destroy])
    end
  end
end
