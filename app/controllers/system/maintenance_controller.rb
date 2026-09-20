# frozen_string_literal: true

module System
  # Gathers the platform-wide operations that destroy data.
  class MaintenanceController < BaseController
    def show
      authorize :maintenance
    end
  end
end
