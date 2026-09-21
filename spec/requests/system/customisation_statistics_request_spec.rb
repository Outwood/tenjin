# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::CustomisationStatistics", :default_creates, type: :request do
  let!(:bought) { create(:customisation, name: "Midnight Theme") }
  let!(:unbought) { create(:customisation, name: "Sunrise Theme") }

  before { create(:customisation_unlock, customisation: bought, user: student) }

  describe "GET /system/customisations/statistics" do
    context "as a super admin" do
      before { sign_in super_admin }

      it "ranks every customisation by how often it was bought" do
        get system_customisation_statistics_path
        expect(Capybara.string(response.body))
          .to have_css("#customisation-statistics tbody tr:first-child", text: "Midnight Theme")
          .and have_css("#customisation-statistics", text: "Sunrise Theme")
      end
    end

    context "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "opens, as the overview already ranks these customisations for them" do
        get system_customisation_statistics_path
        expect(Capybara.string(response.body)).to have_css("#customisation-statistics", text: "Midnight Theme")
      end
    end
  end

  describe "the overview" do
    before { sign_in super_admin }

    it "links to the full report rather than carrying it" do
      get system_root_path
      expect(Capybara.string(response.body))
        .to have_link("All customisation purchases", href: system_customisation_statistics_path)
    end
  end
end
