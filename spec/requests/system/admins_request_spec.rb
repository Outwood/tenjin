# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Admins", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/admins/:id" do
    it "renders the admin show page" do
      get system_admin_path(super_admin)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /system/admins/:id/reset_year" do
    context "with the confirmation typed" do
      let(:params) { {confirmation: "reset year"} }

      it "schedules ResetYearJob" do
        expect {
          post reset_year_system_admin_path(super_admin), params: params
        }.to have_enqueued_job(ResetYearJob)
      end

      it "redirects to system_schools_path" do
        post reset_year_system_admin_path(super_admin), params: params
        expect(response).to redirect_to(system_schools_path)
        expect(flash[:notice]).to start_with("Resetting year data")
      end
    end

    context "with the confirmation mistyped" do
      let(:params) { {confirmation: "reset"} }

      it "schedules nothing" do
        expect {
          post reset_year_system_admin_path(super_admin), params: params
        }.not_to have_enqueued_job(ResetYearJob)
      end

      it "returns to the admin page and says why" do
        post reset_year_system_admin_path(super_admin), params: params
        expect(response).to redirect_to(system_admin_path(super_admin))
        expect(flash[:alert]).to eq("Type reset year to confirm the reset")
      end
    end
  end
end
