# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Invitations", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /admins/invitation/new" do
    it "renders the invitation form via the System::InvitationsController" do
      get new_admin_invitation_path
      expect(response).to have_http_status(:ok)
      expect(controller.class).to eq(System::InvitationsController)
    end

    it "renders inside the admin area" do
      get new_admin_invitation_path
      expect(Capybara.string(response.body)).to have_css("#navbar-main a.nav-link", text: "Schools")
        .and have_title("Invite an Admin · Tenjin admin")
    end
  end
  describe "POST /admins/invitation" do
    let(:params) { {admin: {email: "invited@example.test"}} }

    it "invites an admin" do
      expect { post admin_invitation_path, params: params }.to change(Admin, :count).by(1)
    end

    describe "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "refuses" do
        expect { post admin_invitation_path, params: params }.not_to change(Admin, :count)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end
end
