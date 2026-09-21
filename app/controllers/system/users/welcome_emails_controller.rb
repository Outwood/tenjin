# frozen_string_literal: true

module System
  module Users
    # Sends a user the email that sets up their account.
    class WelcomeEmailsController < BaseController
      def create
        user = authorize find_user, policy_class: System::Users::WelcomeEmailPolicy
        UserMailer.with(user: user).setup_email.deliver_later
        user.send_reset_password_instructions
        redirect_to system_user_path(user), notice: "Setup email sent to #{user.full_name} (#{user.email})"
      end

      private

      def find_user = User.find(params[:user_id])
    end
  end
end
