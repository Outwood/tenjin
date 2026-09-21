# frozen_string_literal: true

module System
  class InvitationsController < Devise::InvitationsController
    # A Devise controller, not a System::BaseController, so it needs the namespace too
    include System::PolicyNamespace

    before_action :authenticate_admin!
    # Accepting an invitation happens signed out, on the public layout
    layout "system", only: %i[new create]

    def new
      authorize current_admin
      super
    end

    def create
      authorize current_admin
      super
    end

    private

    def invite_resource
      super { |admin| admin.role = "school_group" }
    end

    def after_accept_path_for(_resource)
      system_root_path
    end
  end
end
