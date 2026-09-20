# frozen_string_literal: true

module System
  # Decides who may reach the platform's destructive operations.
  class MaintenancePolicy < System::ApplicationPolicy
    def show? = super?
  end
end
