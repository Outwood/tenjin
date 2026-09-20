# frozen_string_literal: true

module System
  class AdminPolicy < System::ApplicationPolicy
    def show? = super?
    def new? = super?
    def manage_roles? = super?
  end
end
