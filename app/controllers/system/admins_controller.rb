# frozen_string_literal: true

module System
  # Lists and revokes the accounts that can sign in to the admin area.
  class AdminsController < BaseController
    def index
      authorize Admin, :index?
      @admins = policy_scope(Admin).order(:email)
    end

    def destroy
      admin = authorize Admin.find(params[:id])
      admin.destroy
      redirect_to system_admins_path, notice: "Revoked #{admin.email}"
    end
  end
end
