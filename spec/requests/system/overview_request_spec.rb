# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Overview", :default_creates, type: :request do
  describe "GET /system" do
    describe "as a super admin" do
      before do
        sign_in super_admin
        get system_root_path
      end

      it "renders the platform activity table" do
        expect(Capybara.string(response.body)).to have_css("#asked_questions")
          .and have_css("#homeworks_completed")
      end
    end

    describe "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_root_path
      end

      it "renders the platform activity table" do
        expect(Capybara.string(response.body)).to have_css("#asked_questions")
      end
    end
  end

  describe "GET /system/schools/stats" do
    it "no longer routes to statistics" do
      sign_in super_admin
      expect { get "/system/schools/stats" }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
