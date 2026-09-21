# frozen_string_literal: true

module System
  module Schools
    # Decides who may queue a school's roster sync.
    class SyncPolicy < System::ApplicationPolicy
      def create? = super?
    end
  end
end
