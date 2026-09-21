# frozen_string_literal: true

module System
  # Decides who may see how often each customisation has been bought.
  class CustomisationStatisticsPolicy < System::ApplicationPolicy
    # Both admin tiers already see the ranking on the overview, retired rows included
    def show? = super? || school_group?
  end
end
