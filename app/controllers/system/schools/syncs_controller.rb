# frozen_string_literal: true

module System
  module Schools
    # Queues a school's roster sync against its MIS.
    class SyncsController < BaseController
      def create
        @school = authorize School.find(params[:school_id]), policy_class: System::Schools::SyncPolicy
        @school.update_attribute(:sync_status, "queued")
        SyncSchoolJob.perform_later @school

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to system_schools_path }
        end
      end
    end
  end
end
