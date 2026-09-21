# frozen_string_literal: true

module System
  # Points a controller at the admin area's own policies, so `authorize @school`
  # reaches System::SchoolPolicy and call sites stay unqualified.
  module PolicyNamespace
    extend ActiveSupport::Concern

    private

    def pundit_namespace(record) = [:system, record]

    def pundit_user = current_admin
  end
end
