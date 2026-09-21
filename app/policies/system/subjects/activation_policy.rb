# frozen_string_literal: true

module System
  module Subjects
    # Decides who may take a subject out of use, and put it back.
    class ActivationPolicy < System::ApplicationPolicy
      def create? = super? && !record.active?
      def destroy? = super? && record.active?
    end
  end
end
