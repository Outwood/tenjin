# frozen_string_literal: true

module Topics
  # Adds questions to a topic from an uploaded JSON file.
  class ImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_topic

    def new
    end

    def create
      if params[:file].nil?
        flash.now[:alert] = "Please attach a file"
        return render :new
      end

      case Question::ImportQuestions.call(data: params[:file].read, topic: @topic, filename: params[:file].original_filename)
      in {success: true, payload: {number_questions_imported:}}
        flash[:notice] = "Imported #{number_questions_imported} questions"
      in {success: false, error:}
        flash[:alert] = "Import failed: #{error}"
      end
      redirect_to topic_questions_path(@topic)
    end

    private

    def set_topic
      @topic = authorize Topic.find(params[:topic_id]), :update?
    end
  end
end
