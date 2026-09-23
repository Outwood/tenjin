# frozen_string_literal: true

module Schools
  # Queues the admin's own school's roster sync.
  class SyncsController < ApplicationController
    before_action :authenticate_user!

    def create
      @school = authorize School.find(params[:school_id]), :sync?
      @school.update_attribute(:sync_status, "queued")
      SyncSchoolJob.perform_later @school

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to school_path(@school) }
      end
    end
  end
end
