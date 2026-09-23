# frozen_string_literal: true

module Schools
  # Gives every pupil and teacher at the admin's own school a new random password, emailed to the admin.
  class PasswordResetsController < ApplicationController
    before_action :authenticate_user!

    def create
      school = authorize School.find(params[:school_id]), :reset_all_passwords?
      ResetUserPasswordsJob.perform_later(current_user)
      flash[:alert] = "Request received.  You will receive an email shortly with usernames and passwords."
      redirect_to school_path(school)
    end
  end
end
