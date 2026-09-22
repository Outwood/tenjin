# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersHelper do
  include ActiveSupport::Testing::TimeHelpers

  describe "#user_status_badge" do
    it "marks an enabled user active" do
      expect(Capybara.string(helper.user_status_badge(build_stubbed(:student))))
        .to have_css(".badge.text-bg-success", exact_text: "Active")
    end

    it "marks a disabled user inactive" do
      expect(Capybara.string(helper.user_status_badge(build_stubbed(:student, disabled: true))))
        .to have_css(".badge.text-bg-secondary", exact_text: "Inactive")
    end
  end

  describe "#last_sign_in" do
    it "says never for a user who has not signed in" do
      expect(helper.last_sign_in(build_stubbed(:student, current_sign_in_at: nil))).to eq("Never")
    end

    context "with a most recent sign-in" do
      let(:user) { build_stubbed(:student, current_sign_in_at: Time.zone.local(2026, 9, 14, 9, 12)) }

      before { travel_to Time.zone.local(2026, 9, 17, 12, 0) }

      it "gives how long ago it was, and when" do
        expect(Capybara.string(helper.last_sign_in(user)))
          .to have_css("time[datetime='2026-09-14T09:12:00Z']", exact_text: "3 days ago")
          .and have_css("small", exact_text: "14 Sep 2026 09:12")
      end
    end
  end
end
