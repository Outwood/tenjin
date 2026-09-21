# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Users::Emails", :default_creates, type: :request do
  let!(:employee) { create(:teacher, school: school) }

  before { sign_in super_admin }

  describe "PATCH /system/users/:user_id/email" do
    it "changes the address and returns to the user" do
      patch system_user_email_path(employee), params: {user: {email: "new-address@example.test"}}

      expect(employee.reload.email).to eq("new-address@example.test")
      expect(response).to redirect_to(system_user_path(employee))
      expect(flash[:notice]).to eq("Updated email to #{employee.full_name}")
    end

    context "when the record refuses the change" do
      let!(:employee) { create(:teacher, :without_upi, school: school) }

      it "says so rather than reporting a change it did not make" do
        expect {
          patch system_user_email_path(employee), params: {user: {email: "new-address@example.test"}}
        }.not_to change { employee.reload.email }

        expect(flash[:alert]).to include("Upi")
      end
    end

    describe "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "refuses" do
        expect {
          patch system_user_email_path(employee), params: {user: {email: "new-address@example.test"}}
        }.not_to change { employee.reload.email }
      end
    end
  end
end
