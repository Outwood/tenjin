# frozen_string_literal: true

module System
  # Decides who may see how often each customisation has been bought.
  class CustomisationStatisticsPolicy < System::ApplicationPolicy
    # Both admin tiers see the top five on the overview, so both may see the rest
    def show? = super? || school_group?
  end
end
