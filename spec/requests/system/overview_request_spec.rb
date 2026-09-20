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

    describe "customisation purchase counts" do
      let(:bought) { create(:customisation, name: "Overview Bought Item") }
      let(:unbought) { create(:customisation, name: "Overview Unbought Item") }

      before do
        sign_in super_admin
        create_list(:customisation_unlock, 2, customisation: bought)
        unbought
        get system_root_path
      end

      it "counts times bought via a left join, including customisations with zero unlocks" do
        page = Capybara.string(response.body)
        expect(page).to have_css("#customisation_#{bought.id} td:last-child", text: "2")
          .and have_css("#customisation_#{unbought.id} td:last-child", text: "0")
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
