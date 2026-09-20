# frozen_string_literal: true

module System
  # Decides who may manage the accounts that can sign in to the admin area.
  class AdminPolicy < System::ApplicationPolicy
    def index? = super?
    def new? = super?

    # Guards System::UsersController#manage_roles, which has no policy of its own
    def manage_roles? = super?

    class Scope < Scope
      def resolve = super? ? scope.all : scope.none
    end
  end
end
