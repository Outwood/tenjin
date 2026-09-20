# frozen_string_literal: true

module System
  # Decides who may clear a year's activity across every school.
  class YearResetPolicy < System::ApplicationPolicy
    def create? = super?
  end
end
