# frozen_string_literal: true

module System
  module Users
    # Decides who may send a user their account setup email.
    class WelcomeEmailPolicy < System::ApplicationPolicy
      def create? = super? && record.employee?
    end
  end
end
