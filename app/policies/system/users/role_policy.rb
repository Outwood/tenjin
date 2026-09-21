# frozen_string_literal: true

module System
  module Users
    # Decides who may grant and revoke a user's roles.
    class RolePolicy < System::ApplicationPolicy
      def create? = super? && record.employee?

      alias_method :destroy?, :create?
    end
  end
end
