# frozen_string_literal: true

class TopicsController < ApplicationController
  before_action :authenticate_user!

  def update
    topic = authorize find_topic

    if topic.update(topic_params)
      head :no_content
    else
      refuse("Topic not renamed: #{topic.errors.full_messages.to_sentence}")
    end
  end

  def destroy
    topic = authorize find_topic

    if topic.destroy
      redirect_to questions_path
    else
      refuse("Topic not deleted")
    end
  end

  private

  def find_topic
    Topic.find(params[:id])
  end

  def topic_params
    params.require(:topic).permit(:name, :default_lesson_id)
  end
end
