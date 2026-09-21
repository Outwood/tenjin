# frozen_string_literal: true

module System
  module Users
    # Decides who may change a user's email address.
    class EmailPolicy < System::ApplicationPolicy
      def update? = super? && record.employee?
    end
  end
end
