# frozen_string_literal: true

require "rails_helper"

RSpec.describe "customisations", :default_creates do
  let(:school_group_admin) { create(:school_group_admin) }

  describe "admin navbar" do
    before do
      sign_in admin
      get system_schools_path
    end

    context "as a super admin" do
      let(:admin) { super_admin }

      it "links to customisations" do
        expect(response.body).to include(system_customisations_path)
      end
    end

    context "as a school group admin" do
      let(:admin) { school_group_admin }

      it "does not link to customisations" do
        expect(response.body).not_to include(system_customisations_path)
      end
    end
  end

  describe "user navbar" do
    before do
      sign_in student
      get dashboard_path
    end

    it "links to the customisation shop from the challenge star and points" do
      expect(response.body).to include(customisations_path)
    end
  end

  describe "GET /shop" do
    let!(:customisation) { create(:customisation) }

    before { sign_in student }

    context "while an admin is signed in as the student" do
      before do
        sign_in super_admin
        get customisations_path
      end

      it "offers the shop rather than the admin controls" do
        expect(Capybara.string(response.body))
          .to have_button("Buy")
          .and have_no_link("Edit", href: edit_system_customisation_path(customisation))
      end
    end
  end

  describe "POST /shop/:customisation_id/unlock" do
    before { sign_in student }

    context "with enough points for the customisation" do
      let(:student) { create(:student, school: school, challenge_points: 10) }
      let(:customisation) { create(:dashboard_customisation, cost: 6) }

      it "unlocks it for the student and spends the points" do
        expect { post customisation_unlock_path(customisation) }
          .to change { CustomisationUnlock.where(user: student, customisation: customisation).count }.by(1)
          .and change { student.reload.challenge_points }.from(10).to(4)
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to eq("Congratulations! You have bought #{customisation.name}")
      end
    end

    context "with a non-existent customisation id" do
      it "redirects to the dashboard" do
        post customisation_unlock_path(customisation_id: rand(200..300))
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
