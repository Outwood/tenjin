# frozen_string_literal: true

module System
  module Users
    # Changes a user's email address.
    class EmailsController < BaseController
      def update
        user = authorize find_user, policy_class: System::Users::EmailPolicy
        user.update(email: email_params[:email])
        redirect_to system_user_path(user), notice: "Updated email to #{user.full_name}"
      end

      private

      def find_user = User.find(params[:user_id])

      def email_params = params.require(:user).permit(:email)
    end
  end
end
