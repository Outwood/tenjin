# frozen_string_literal: true

module System
  # Decides who may see the platform overview.
  class OverviewPolicy < System::ApplicationPolicy
    def show? = super? || school_group?
  end
end
