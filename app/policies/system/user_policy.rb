# frozen_string_literal: true

module System
  # Decides who may look up the platform's users.
  class UserPolicy < System::ApplicationPolicy
    # Either tier can already reach every user through the school pages
    def index? = true

    alias_method :show?, :index?

    class Scope < Scope
      def resolve = scope.all
    end
  end
end
