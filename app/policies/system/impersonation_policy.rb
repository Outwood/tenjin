# frozen_string_literal: true

module System
  # Decides who may sign in as one of the platform's users.
  class ImpersonationPolicy < System::ApplicationPolicy
    # Both tiers may impersonate any user: `admins` carries no school_group_id,
    # so a restricted admin has no group to scope the target against. Scoping
    # belongs here, where the target arrives as the record. A disabled user's
    # sign-in is refused, so impersonating one would only bounce the admin
    def create? = (super? || school_group?) && !record.disabled?

    # Only drops the admin's own user session, so no level applies
    def destroy? = true
  end
end
