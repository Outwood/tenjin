# frozen_string_literal: true

module System
  module Maintenance
    # Clears a year's activity across every school.
    class YearResetsController < BaseController
      # Typed to confirm a year reset, which deletes every school's classes
      RESET_YEAR_CONFIRMATION = "reset year"

      def create
        authorize :year_reset

        unless params[:confirmation] == RESET_YEAR_CONFIRMATION
          return redirect_to system_maintenance_path,
            alert: "Type #{RESET_YEAR_CONFIRMATION} to confirm the reset"
        end

        ResetYearJob.perform_later
        redirect_to system_root_path,
          notice: "Resetting year data: classes, challenges and leaderboards are being cleared"
      end
    end
  end
end
