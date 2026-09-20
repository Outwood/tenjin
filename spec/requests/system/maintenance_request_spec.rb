# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Maintenance", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/maintenance" do
    it "offers the year reset behind a typed confirmation" do
      get system_maintenance_path
      expect(Capybara.string(response.body))
        .to have_css("#reset-year-heading", text: "Reset year data")
        .and have_button("Reset Year Data", disabled: true)
    end

    describe "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "refuses" do
        get system_maintenance_path
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "POST /system/maintenance/year_reset" do
    context "with the confirmation typed" do
      let(:params) { {confirmation: "reset year"} }

      it "schedules ResetYearJob" do
        expect {
          post system_maintenance_year_reset_path, params: params
        }.to have_enqueued_job(ResetYearJob)
      end

      it "returns to the overview and says what is happening" do
        post system_maintenance_year_reset_path, params: params
        expect(response).to redirect_to(system_root_path)
        expect(flash[:notice]).to start_with("Resetting year data")
      end
    end

    context "with the confirmation mistyped" do
      let(:params) { {confirmation: "reset"} }

      it "schedules nothing" do
        expect {
          post system_maintenance_year_reset_path, params: params
        }.not_to have_enqueued_job(ResetYearJob)
      end

      it "returns to the maintenance page and says why" do
        post system_maintenance_year_reset_path, params: params
        expect(response).to redirect_to(system_maintenance_path)
        expect(flash[:alert]).to eq("Type reset year to confirm the reset")
      end
    end
  end
end
