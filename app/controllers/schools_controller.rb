# frozen_string_literal: true

class SchoolsController < ApplicationController
  before_action :authenticate_user!

  def show
    @school = authorize find_school
  end

  def sync
    @school = authorize find_school
    @school.update_attribute(:sync_status, "queued")
    SyncSchoolJob.perform_later @school

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to school_path(@school) }
    end
  end

  def reset_all_passwords
    school = authorize find_school
    ResetUserPasswordsJob.perform_later(current_user)
    flash[:alert] = "Request received.  You will receive an email shortly with usernames and passwords."
    redirect_to school_path(school)
  end

  private

  def find_school
    School.find(params[:id])
  end
end
