# frozen_string_literal: true

require "rails_helper"

RSpec.describe "School admin views user list", :default_creates, :js do
  let!(:student_enrollment) { create(:enrollment, user: student, classroom: classroom) }

  before do
    sign_in school_admin
    visit(users_path)
  end

  describe "a row's password reset" do
    # One smoke for the actions menu, its Bootstrap dropdown and modal, and the password-reset Stimulus
    # controller, which the employee table and classroom page share; the controller's branches are in
    # spec/javascript/controllers/password_reset_controller.test.js
    it "asks first, then shows the new password" do
      name = "#{student.forename} #{student.surname}"
      within("#students-table") do
        click_button("Actions for #{name}", enable_aria_label: true)
        click_button("Reset password")
      end

      within(".modal", text: "Reset #{name}'s password?") { click_button("Reset password") }

      expect(page).to have_css(".modal-title", exact_text: "New password for #{name}")
        .and have_css("[data-password-reset-target='password']", text: /\S/)
    end
  end

  describe "the student table" do
    # Tabulator smoke, for the classroom page too; which users each table lists is covered in spec/requests/users_request_spec.rb
    context "with more than one page of students" do
      before do
        student.update!(surname: "Zzzqx")
        create_list(:enrollment, 32, classroom: classroom)
        visit(users_path)
      end

      it "paginates to 10 rows and filters by name" do
        within ".table-responsive:has(#students-table)" do
          # Also waits for Tabulator to build, so the filter input is not dropped
          expect(page).to have_css(".student-row", count: 10)
          fill_in "Search pupils…", with: student.surname
          expect(page).to have_css(".student-row", count: 1)
            .and have_css(".student-row[data-id='#{student.id}']")
        end
      end
    end

    # Smoke for the synthetic click reaching Tabulator's sort; the key handling is in
    # spec/javascript/controllers/datatable_controller.test.js
    it "sorts by a heading from the keyboard" do
      heading = find("#students-table .tabulator-col[tabulator-field='name']")
      expect(heading["aria-sort"]).to eq("ascending")

      execute_script("arguments[0].focus()", heading)
      page.driver.browser.keyboard.type(:Enter)

      expect(page).to have_css("#students-table .tabulator-col[tabulator-field='name'][aria-sort='descending']")
    end
  end
end
