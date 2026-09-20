# frozen_string_literal: true

module System
  # Decides who may see the platform overview.
  class OverviewPolicy < System::ApplicationPolicy
    # Both admin tiers manage schools, so both need the platform overview.
    def show? = true
  end
end
