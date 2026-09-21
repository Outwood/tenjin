# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Super manages school staff", :default_creates, :js do
  before { sign_in super_admin }

  shared_examples "a manageable role" do |role_name:, requires_subject:|
    let!(:quiz_subject) { create(:subject) } if requires_subject

    before { visit(system_school_staff_index_path(teacher.school)) }

    it "adds the role to the user" do
      select quiz_subject.name, from: "user[subject]" if requires_subject
      select role_name.humanize, from: "user[role]"
      click_button "Add Role"
      expect(page).to have_css("#roles-table", text: role_name.humanize)
    end

    context "when the role is already assigned" do
      before do
        requires_subject ? teacher.add_role(role_name.to_sym, quiz_subject) : teacher.add_role(role_name.to_sym)
        visit(system_user_path(teacher))
      end

      it "removes the role from the user" do
        click_button "Revoke"
        expect(page).to have_no_css("#roles-table")
      end
    end
  end

  describe "school admin role" do
    include_examples "a manageable role", role_name: "school_admin", requires_subject: false
  end

  describe "question author role" do
    include_examples "a manageable role", role_name: "question_author", requires_subject: true
  end

  describe "lesson author role" do
    include_examples "a manageable role", role_name: "lesson_author", requires_subject: true
  end

  describe "employees list" do
    before do
      teacher
      visit(system_school_staff_index_path(school))
    end

    it "lists employees from the school" do
      expect(page).to have_css(".employee-row", count: 1)
    end
  end
end
