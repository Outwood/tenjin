# frozen_string_literal: true

module System
  class AdminsController < BaseController
    # Typed to confirm a year reset, which deletes every school's classes
    RESET_YEAR_CONFIRMATION = "reset year"

    def show
      authorize current_admin
    end

    def reset_year
      authorize current_admin
      unless params[:confirmation] == RESET_YEAR_CONFIRMATION
        return redirect_to system_admin_path(current_admin), alert: "Type #{RESET_YEAR_CONFIRMATION} to confirm the reset"
      end

      ResetYearJob.perform_later
      redirect_to system_schools_path, notice: "Resetting year data: classes, challenges and leaderboards are being cleared"
    end
  end
end
