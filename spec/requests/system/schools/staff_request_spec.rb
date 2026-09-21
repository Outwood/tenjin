# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Schools::Staff", :default_creates, type: :request do
  let!(:employee) { create(:teacher, school: school, forename: "Ada", surname: "Lovelace") }
  let!(:pupil) { create(:student, school: school, forename: "Grace", surname: "Hopper") }
  let!(:elsewhere) { create(:teacher, school: create(:school), forename: "Alan", surname: "Turing") }

  describe "GET /system/schools/:school_id/staff" do
    context "as a super admin" do
      before do
        sign_in super_admin
        get system_school_staff_index_path(school)
      end

      it "lists this school's employees and no one else" do
        expect(Capybara.string(response.body))
          .to have_link("Ada Lovelace", href: system_user_path(employee))
          .and have_no_link("Grace Hopper", href: system_user_path(pupil))
          .and have_no_link("Alan Turing", href: system_user_path(elsewhere))
      end

      it "breadcrumbs back to the school" do
        expect(Capybara.string(response.body)).to have_link(school.name, href: system_school_path(school))
      end

      it "offers a role grant per employee" do
        expect(Capybara.string(response.body)).to have_css("#add-role-#{employee.id}")
      end

      it "renders every id once" do
        ids = Capybara.string(response.body).all("[id]").map { |element| element[:id] }
        expect(ids.tally.select { |_id, count| count > 1 }).to be_empty
      end

      it "leaves the role unchosen, so no click grants one by default" do
        expect(Capybara.string(response.body))
          .to have_css("select[name='user[role]'][required] option:first-child[value='']", exact_text: "Choose role…")
          .and have_no_css("select[name='user[role]'] option[selected]")
      end
    end

    context "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_school_staff_index_path(school)
      end

      it "refuses" do
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end
end
