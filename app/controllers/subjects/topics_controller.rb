# frozen_string_literal: true

module Subjects
  # Starts a new topic in a subject, ready for its author to rename.
  class TopicsController < ApplicationController
    before_action :authenticate_user!

    def create
      subject = Subject.find(params[:subject_id])
      topic = authorize Topic.new(subject: subject, active: true, name: "New topic")
      topic.save!

      redirect_to topic_questions_path(topic)
    end
  end
end
