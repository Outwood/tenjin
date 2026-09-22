# frozen_string_literal: true

require "rails_helper"

RSpec.describe "School admin views user list", :default_creates, :js do
  let!(:student_enrollment) { create(:enrollment, user: student, classroom: classroom) }

  before do
    sign_in school_admin
    visit(users_path)
  end

  describe "the Reset Password link" do
    # One smoke for the password-reset Stimulus controller, which the employee table shares;
    # the password the action returns is covered in spec/requests/users_request_spec.rb
    it "replaces the Reset Password link with the new password" do
      within "#students-table" do
        click_link("Reset Password")
        expect(page).to have_no_link("Reset Password").and have_css(".new-password")
      end
    end
  end

  describe "the student table" do
    # Tabulator smoke; which users each table lists is covered in spec/requests/users_request_spec.rb
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
          fill_in "Search…", with: student.surname
          expect(page).to have_css(".student-row", count: 1)
            .and have_css(".student-row[data-id='#{student.id}']")
        end
      end
    end
  end
end
