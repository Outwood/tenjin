# frozen_string_literal: true

require "rails_helper"

# A throwaway controller that uses `System::BaseController` so we can verify
# the auth gate and the Pundit namespace overrides without touching real
# admin routes yet.
module System
  class PingsController < BaseController
    # The throwaway controller only exercises `authorize`; bypass the
    # `verify_policy_scoped` after-action inherited from ApplicationController.
    skip_after_action :verify_policy_scoped, only: :index

    def index
      authorize :ping, :index?
      head :ok
    end
  end
end

module System
  class PingPolicy < System::ApplicationPolicy
    def index?
      admin.is_a?(Admin)
    end
  end
end

RSpec.describe "System::BaseController", type: :request do
  before do
    Rails.application.routes.draw do
      namespace :system do
        root to: "overview#show"
        resources :schools, only: [:index]
        resources :subjects, only: [:index]
        resources :customisations, only: [:index]
        resources :school_groups, only: [:index]
        resources :admins, only: [:show]
        resources :users, only: [] do
          collection do
            get :manage_roles
          end
        end
        resources :pings, only: [:index]
      end
      devise_for :admins
      devise_for :users
    end
  end

  after { Rails.application.reload_routes! }

  context "with no admin signed in" do
    it "redirects to the admin sign-in page" do
      get "/system/pings"
      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  context "with an admin signed in", :default_creates do
    it "routes authorize through the System:: namespace" do
      sign_in super_admin
      get "/system/pings"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "the main navigation", :default_creates do
    before do
      sign_in super_admin
      get system_root_path
    end

    it "reaches the overview through the brand link, not a named one" do
      expect(Capybara.string(response.body))
        .to have_css("a.navbar-brand[href='#{system_root_path}']")
        .and have_no_link("Statistics")
    end
  end
end
