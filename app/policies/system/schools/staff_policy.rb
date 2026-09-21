# frozen_string_literal: true

module System
  module Schools
    # Decides who may see and change a school's employees and their roles.
    class StaffPolicy < System::ApplicationPolicy
      def index? = super?
    end
  end
end
