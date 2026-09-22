# frozen_string_literal: true

require "rails_helper"

RSpec.describe "user controller", :default_creates do
  describe "GET #index authorization" do
    context "as a teacher" do
      before do
        sign_in teacher
        get users_path
      end

      it "is not authorized" do
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized to perform this action.")
      end
    end

    context "as a student" do
      before do
        sign_in student
        get users_path
      end

      it "is not authorized" do
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized to perform this action.")
      end
    end

    context "as a school admin" do
      before do
        sign_in school_admin
        get users_path
      end

      it "renders the user list" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET #index" do
    let!(:student) { super() }
    let!(:other_teacher) { create(:teacher, school: school) }
    let!(:other_school_student) { create(:student, school: create(:school)) }

    before do
      sign_in school_admin
      get users_path
    end

    it "lists the school's students and not other schools'" do
      expect(Capybara.string(response.body))
        .to have_css("#students-table .student-row[data-id='#{student.id}']")
        .and have_no_css("#students-table .student-row[data-id='#{other_school_student.id}']")
    end

    it "lists teachers and school admins as employees" do
      expect(Capybara.string(response.body))
        .to have_css("#employees-table .employee-row[data-id='#{other_teacher.id}']")
        .and have_css("#employees-table .employee-row[data-id='#{school_admin.id}']")
    end

    it "marks the School menu and its Users item as current" do
      expect(Capybara.string(response.body))
        .to have_css("#school-menu .dropdown-toggle.active")
        .and have_css("#school-menu a.active[aria-current='page'][href='#{users_path}']", exact_text: "Users")
    end

    it "hides employees from other schools"
  end

  describe "GET #show authorization" do
    let(:other_employee) { create(:teacher, school: school) }

    context "as a teacher viewing a student" do
      before do
        sign_in teacher
        get user_path(student)
      end

      it "renders the page with the password reset form" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="user_password"')
      end
    end

    context "as a teacher viewing another employee" do
      before do
        sign_in teacher
        get user_path(other_employee)
      end

      it "redirects to the root path" do
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a teacher viewing a school admin" do
      before do
        sign_in teacher
        get user_path(school_admin)
      end

      it "redirects to the root path" do
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET #show" do
    describe "the homework table" do
      let!(:student_enrollment) { create(:enrollment, user: student, classroom: classroom) }
      let!(:teacher_enrollment) { create(:enrollment, user: teacher, classroom: classroom) }
      let!(:homework) { create(:homework, classroom: classroom, topic: topic) }
      let(:status_cell) { ".homework-row[data-homework='#{homework.id}'] td:last-child" }

      before { sign_in teacher }

      context "when the homework is not completed" do
        before { get user_path(student) }

        it "shows a cross icon" do
          expect(Capybara.string(response.body)).to have_css("#{status_cell} i.fa-times")
            .and have_no_css("#{status_cell} i.fa-check")
        end
      end

      context "when the homework is completed" do
        before do
          homework.homework_progresses.find_by!(user: student).update!(completed: true)
          get user_path(student)
        end

        it "shows a check icon" do
          expect(Capybara.string(response.body)).to have_css("#{status_cell} i.fa-check")
            .and have_no_css("#{status_cell} i.fa-times")
        end
      end

      context "when the student is enrolled in a second classroom" do
        let(:second_classroom) { create(:classroom, school: school) }
        let!(:second_enrollment) { create(:enrollment, user: student, classroom: second_classroom) }
        let!(:homework_different_class) { create(:homework, classroom: second_classroom, topic: topic) }

        before { get user_path(student) }

        it "hides homework from classrooms the teacher does not belong to" do
          expect(Capybara.string(response.body))
            .to have_css(".homework-row[data-homework='#{homework.id}']")
            .and have_no_css(".homework-row[data-homework='#{homework_different_class.id}']")
        end
      end
    end

    describe "the Google account buttons" do
      context "with a linked Google account" do
        before do
          sign_in student
          get user_path(student)
        end

        it "offers to unlink the account" do
          expect(Capybara.string(response.body)).to have_button("Unlink #{student.oauth_email}")
            .and have_no_css("#loginGoogle")
        end
      end

      context "with no linked Google account" do
        let(:unlinked_student) { create(:student, :no_oauth, school: school) }

        before do
          sign_in unlinked_student
          get user_path(unlinked_student)
        end

        it "offers to link the account" do
          expect(Capybara.string(response.body)).to have_css("#loginGoogle")
            .and have_no_button("Unlink")
        end
      end
    end
  end

  describe "PATCH #update" do
    let(:new_password) { "correct horse battery" }

    before { sign_in teacher }

    context "with a new password" do
      before { patch user_path(student), params: {user: {password: new_password}} }

      it "changes the password" do
        expect(student.reload).to be_valid_password(new_password)
      end

      it "redirects to the record with a confirmation" do
        expect(response).to redirect_to(user_path(student))
        follow_redirect!
        expect(response.body).to include("Password successfully updated")
      end
    end

    context "with a blank password" do
      before { patch user_path(student), params: {user: {password: ""}} }

      it "leaves the password alone" do
        expect { student.reload }.not_to change(student, :encrypted_password)
      end

      it "says so rather than reporting a change it did not make" do
        expect(flash[:alert]).to eq("Password can't be blank")
        expect(flash[:notice]).to be_nil
      end
    end

    context "when the record refuses the change" do
      let!(:legacy_student) { create(:student, :without_upi, school: school) }

      before { patch user_path(legacy_student), params: {user: {password: new_password}} }

      it "leaves the password alone" do
        expect { legacy_student.reload }.not_to change(legacy_student, :encrypted_password)
      end

      it "reports what the record refused, and that nothing changed" do
        expect(flash[:alert]).to eq("Password not changed: Upi can't be blank")
        expect(flash[:notice]).to be_nil
      end
    end
  end

  describe "PATCH #reset_password" do
    before { sign_in school_admin }

    context "with a resettable student" do
      before { patch reset_password_user_path(student) }

      it "returns a password that now signs the student in" do
        expect(response.parsed_body).to include("id" => student.id)
        expect(student.reload).to be_valid_password(response.parsed_body.fetch("password"))
      end
    end

    context "when the record refuses the change" do
      let!(:legacy_student) { create(:student, :without_upi, school: school) }

      before { patch reset_password_user_path(legacy_student) }

      it "hands back no password to read out" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).not_to have_key("password")
      end

      it "leaves the password alone" do
        expect { legacy_student.reload }.not_to change(legacy_student, :encrypted_password)
      end
    end
  end

  describe "DELETE #unlink_oauth_account" do
    before do
      sign_in student
      delete unlink_oauth_account_user_path(student)
    end

    it "clears the linked account" do
      expect(student.reload).to have_attributes(oauth_uid: "", oauth_email: "", oauth_provider: "")
    end

    it "redirects to the user's record" do
      expect(response).to redirect_to(user_path(student))
    end
  end
end
