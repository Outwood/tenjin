# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Impersonations", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "POST /system/impersonation" do
    before { post system_impersonation_path, params: {user_id: student.id} }

    it "signs in as the target user and redirects to root" do
      expect(response).to redirect_to(root_url)
    end

    it "keeps the admin signed in" do
      get system_schools_path
      expect(response).to have_http_status(:ok)
    end

    it "leaves the user's own sign-in record untouched" do
      expect(student.reload).to have_attributes(sign_in_count: 0, current_sign_in_at: nil)
    end
  end

  describe "POST /system/impersonation for a disabled user" do
    let(:leaver) { create(:student, school: school, disabled: true) }

    before { post system_impersonation_path, params: {user_id: leaver.id} }

    it "refuses, since their sign-in would only bounce the admin" do
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "DELETE /system/impersonation" do
    let(:admin) { super_admin }

    before do
      sign_in admin
      post system_impersonation_path, params: {user_id: student.id}
      delete system_impersonation_path
    end

    it "returns to the admin area and says who was signed out" do
      expect(response).to redirect_to(system_root_path)
      expect(flash[:notice]).to eq("Signed out #{student.full_name}")
    end

    it "ends the user session" do
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "keeps the admin signed in" do
      get system_schools_path
      expect(response).to have_http_status(:ok)
    end

    describe "as a school group admin" do
      let(:admin) { create(:school_group_admin) }

      it "returns to the admin area" do
        expect(response).to redirect_to(system_root_path)
      end
    end
  end

  describe "the impersonation banner" do
    context "after becoming a user" do
      before { post system_impersonation_path, params: {user_id: student.id} }

      it "names the user on their pages, under the user nav, with a way back to the admin area" do
        get dashboard_path
        expect(Capybara.string(response.body))
          .to have_css("#impersonation", text: "Viewing as #{student.full_name}")
          .and have_link("Admin area", href: system_root_path)
          .and have_button("Stop viewing")
          .and have_css("#current_user")
          .and have_no_link("Schools", href: system_schools_path)
      end

      it "names the user on admin pages, under the admin nav, with a way back to them" do
        get system_schools_path
        expect(Capybara.string(response.body))
          .to have_css("#impersonation", text: "Also signed in as #{student.full_name}")
          .and have_link("Back to their pages", href: dashboard_path)
          .and have_button("Sign them out")
          .and have_link("Schools", href: system_schools_path)
          .and have_no_css("#current_user")
      end
    end

    context "without becoming a user" do
      it "is absent from admin pages" do
        get system_schools_path
        expect(Capybara.string(response.body)).to have_no_css("#impersonation")
      end

      describe "as a student" do
        before do
          sign_out super_admin
          sign_in student
        end

        it "is absent from their pages" do
          get dashboard_path
          expect(Capybara.string(response.body)).to have_no_css("#impersonation")
        end
      end
    end
  end
end
