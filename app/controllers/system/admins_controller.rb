# frozen_string_literal: true

module System
  # Lists the accounts that can sign in to the admin area.
  class AdminsController < BaseController
    def index
      authorize Admin, :index?
      @admins = policy_scope(Admin).order(:email)
    end
  end
end
