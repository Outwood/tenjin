# frozen_string_literal: true

module Subjects
  # Adds a named topic to a subject's question bank.
  class TopicsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_subject

    def new
      @topic = authorize @subject.topics.new
    end

    def create
      @topic = authorize @subject.topics.new(topic_params)

      if @topic.save
        redirect_to topic_questions_path(@topic), notice: "Topic created"
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def set_subject
      @subject = Subject.find(params[:subject_id])
    end

    def topic_params
      params.require(:topic).permit(:name)
    end
  end
end
