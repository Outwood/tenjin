# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Users::Roles", :default_creates, type: :request do
  let!(:employee) { create(:teacher, school: school) }
  let(:other_subject) { create(:subject) }

  describe "POST /system/users/:user_id/roles" do
    before { sign_in super_admin }

    it "grants a subject-scoped role" do
      post system_user_roles_path(employee), params: {user: {role: "lesson_author", subject: quiz_subject.id}}
      expect(employee.reload).to have_role(:lesson_author, quiz_subject)
      expect(response).to redirect_to(system_user_path(employee))
    end

    it "grants a global role" do
      post system_user_roles_path(employee), params: {user: {role: "school_admin"}}
      expect(employee.reload).to have_role(:school_admin)
    end

    it "refuses a subject-scoped role with no subject" do
      post system_user_roles_path(employee), params: {user: {role: "lesson_author", subject: ""}}
      expect(flash[:alert]).to eq("Must include a subject with a lesson or question author role")
    end

    it "refuses with no role chosen" do
      post system_user_roles_path(employee), params: {user: {role: ""}}
      expect(employee.reload.roles).to be_empty
      expect(flash[:alert]).to eq("Role not found")
    end

    describe "for a student" do
      let!(:employee) { create(:student, school: school) }

      it "refuses" do
        post system_user_roles_path(employee), params: {user: {role: "school_admin"}}
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "DELETE /system/users/:user_id/roles/:id" do
    before do
      sign_in super_admin
      employee.add_role(:lesson_author, quiz_subject)
      employee.add_role(:lesson_author, other_subject)
    end

    it "revokes only the named grant" do
      role = Role.find_by!(name: "lesson_author", resource: quiz_subject)
      delete system_user_role_path(employee, role)

      expect(employee.reload).not_to have_role(:lesson_author, quiz_subject)
      expect(employee).to have_role(:lesson_author, other_subject)
    end

    it "refuses a grant held by another user" do
      elsewhere = create(:teacher, school: school)
      elsewhere.add_role(:school_admin)
      role = Role.find_by!(name: "school_admin")

      expect { delete system_user_role_path(employee, role) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "signed in as a user rather than an admin" do
    before { sign_in student }

    it "requires admin authentication" do
      post system_user_roles_path(employee), params: {user: {role: "school_admin"}}
      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
