# frozen_string_literal: true

module System
  # The admin's session as one of the platform's users.
  class ImpersonationsController < BaseController
    def create
      user = User.find(params.require(:user_id))
      authorize user, policy_class: System::ImpersonationPolicy

      sign_in(:user, user)
      redirect_to root_url
    end

    def destroy
      authorize :impersonation

      user = current_user
      sign_out(:user)
      redirect_to system_root_path, notice: ("Signed out #{user.full_name}" if user)
    end
  end
end
