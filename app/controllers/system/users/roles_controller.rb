# frozen_string_literal: true

module System
  module Users
    # Grants and revokes a user's roles.
    class RolesController < BaseController
      def create
        user = authorize find_user, policy_class: System::Users::RolePolicy
        change_role(user, role: role_params[:role], subject: role_params[:subject], action: :add)
      end

      def destroy
        user = authorize find_user, policy_class: System::Users::RolePolicy
        role = user.roles.find(params[:id])
        change_role(user, role: role.name, subject: role.resource_id, action: :remove)
      end

      private

      def change_role(user, role:, subject:, action:)
        result = User::ChangeUserRole.call(user: user, role: role, action: action, subject: subject)

        case result
        in {success: true}
          redirect_to system_user_path(user)
        in {success: false, error:}
          redirect_to system_user_path(user), alert: error
        end
      end

      def find_user = User.find(params[:user_id])

      def role_params = params.require(:user).permit(:role, :subject)
    end
  end
end
