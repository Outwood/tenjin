# frozen_string_literal: true

module System
  # Decides who may sign in as one of the platform's users.
  class ImpersonationPolicy < System::ApplicationPolicy
    def create? = super? || school_group?

    # Only drops the admin's own user session, so no level applies
    def destroy? = true
  end
end
