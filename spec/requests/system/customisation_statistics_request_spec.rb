# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::CustomisationStatistics", :default_creates, type: :request do
  let!(:bought) { create(:customisation, name: "Midnight Theme") }
  let!(:unbought) { create(:customisation, name: "Sunrise Theme") }

  before do
    create(:customisation_unlock, customisation: bought, user: student)
    sign_in super_admin
  end

  describe "GET /system/customisations/statistics" do
    it "ranks every customisation by how often it was bought" do
      get system_customisation_statistics_path
      expect(Capybara.string(response.body))
        .to have_css("#customisation-statistics tbody tr:first-child", text: "Midnight Theme")
        .and have_css("#customisation-statistics", text: "Sunrise Theme")
    end
  end

  describe "the overview" do
    it "links to the full report rather than carrying it" do
      get system_root_path
      expect(Capybara.string(response.body))
        .to have_link("All customisation purchases", href: system_customisation_statistics_path)
    end
  end
end
