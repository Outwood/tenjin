# frozen_string_literal: true

module Subjects
  # A subject's questions that students have flagged, most flagged first.
  class FlaggedQuestionsController < ApplicationController
    before_action :authenticate_user!

    def index
      @subject = authorize Subject.find(params[:subject_id]), :flagged_questions?
      # The authorized subject bounds the list
      skip_policy_scope
      @questions = @subject.flagged_questions
    end
  end
end
