# frozen_string_literal: true

module System
  # Resolves Pundit against the admin area's own policies, so `authorize @school`
  # reaches System::SchoolPolicy and call sites stay unqualified.
  module PolicyNamespace
    extend ActiveSupport::Concern

    private

    def authorize(record, query = nil, policy_class: nil)
      super([:system, record], query, policy_class: policy_class)
    end

    def policy_scope(scope, policy_scope_class: nil)
      super([:system, scope], policy_scope_class: policy_scope_class)
    end

    def policy(record)
      super([:system, record])
    end

    def pundit_user
      current_admin
    end
  end
end
