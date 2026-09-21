# frozen_string_literal: true

module System
  # Decides who may manage the accounts that can sign in to the admin area.
  class AdminPolicy < System::ApplicationPolicy
    def index? = super?
    def create? = super?

    # Refusing self-revocation is also what keeps a last super admin in place:
    # only a super admin may revoke, and revoking anyone else leaves them behind
    def destroy? = super? && record != admin

    class Scope < Scope
      def resolve = super? ? scope.all : scope.none
    end
  end
end
