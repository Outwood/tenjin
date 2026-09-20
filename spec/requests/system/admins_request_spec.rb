# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Admins", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/admins" do
    let!(:other_admin) { create(:school_group_admin, email: "listed-admin@example.test") }

    describe "as a super admin" do
      before { get system_admins_path }

      it "lists every admin account with its role" do
        expect(Capybara.string(response.body))
          .to have_css("##{ActionView::RecordIdentifier.dom_id(other_admin)}", text: "listed-admin@example.test")
          .and have_css("##{ActionView::RecordIdentifier.dom_id(other_admin)}", text: "School group")
      end

      it "offers no way to revoke the signed-in admin" do
        expect(Capybara.string(response.body))
          .to have_css("##{ActionView::RecordIdentifier.dom_id(other_admin)} button", text: "Revoke")
          .and have_no_css("##{ActionView::RecordIdentifier.dom_id(super_admin)} button", text: "Revoke")
      end
    end

    describe "as a school group admin" do
      before do
        sign_in other_admin
        get system_admins_path
      end

      it "refuses" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "DELETE /system/admins/:id" do
    let!(:other_admin) { create(:school_group_admin) }

    it "revokes the account and says so" do
      expect { delete system_admin_path(other_admin) }.to change(Admin, :count).by(-1)
      expect(response).to redirect_to(system_admins_path)
      expect(flash[:notice]).to eq("Revoked #{other_admin.email}")
    end

    it "refuses to revoke the signed-in admin" do
      expect { delete system_admin_path(super_admin) }.not_to change(Admin, :count)
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end
  end
end
