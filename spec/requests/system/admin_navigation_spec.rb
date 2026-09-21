# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the admin navigation", :default_creates, type: :request do
  describe "GET /system" do
    context "as a super admin" do
      before do
        sign_in super_admin
        get system_root_path
      end

      it "reaches the overview through the brand link" do
        expect(Capybara.string(response.body))
          .to have_css("a.navbar-brand[href='#{system_root_path}'][aria-current='page']")
      end

      it "has no link to the removed Statistics page" do
        expect(Capybara.string(response.body)).to have_no_link("Statistics")
      end

      it "links to the user directory in place of the role registry" do
        expect(Capybara.string(response.body))
          .to have_link("Users", href: system_users_path)
          .and have_no_link("Roles")
      end

      it "gathers configuration under a Settings menu" do
        expect(Capybara.string(response.body).find("#settings-menu"))
          .to have_link("Admins", href: system_admins_path)
          .and have_link("School Groups", href: system_school_groups_path)
          .and have_link("Maintenance", href: system_maintenance_path)
      end
    end

    context "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_root_path
      end

      it "shows Schools, Subjects and Users, not the super admin's links" do
        expect(Capybara.string(response.body))
          .to have_link("Schools")
          .and have_link("Subjects")
          .and have_link("Users", href: system_users_path)
          .and have_no_link("Customisations")
          .and have_no_link("School Groups")
      end

      it "has no Settings menu" do
        expect(Capybara.string(response.body)).to have_no_css("#settings-menu")
      end
    end
  end

  # The public layout renders this same navigation for a signed-in admin
  describe "GET / as a super admin" do
    before do
      sign_in super_admin
      get root_path
    end

    it "builds the Settings menu outside the admin area" do
      expect(response).to have_http_status(:ok)
      expect(Capybara.string(response.body).find("#settings-menu"))
        .to have_link("Admins", href: system_admins_path)
    end
  end
end
