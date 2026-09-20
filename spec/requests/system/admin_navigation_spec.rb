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
    end

    context "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_root_path
      end

      it "shows Schools and Subjects, not the super admin's links" do
        expect(Capybara.string(response.body))
          .to have_link("Schools")
          .and have_link("Subjects")
          .and have_no_link("Customisations")
          .and have_no_link("School Groups")
          .and have_no_link("Roles")
      end
    end
  end
end
