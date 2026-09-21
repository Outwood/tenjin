# frozen_string_literal: true

module System
  class SubjectPolicy < System::ApplicationPolicy
    def update? = super?

    alias_method :create?, :update?
    alias_method :edit?, :update?
    alias_method :new?, :update?

    class Scope < Scope
      def resolve = scope.all
    end
  end
end
