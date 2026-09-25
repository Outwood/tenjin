# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", :default_creates do
  include ActiveSupport::Testing::TimeHelpers

  describe "signing in" do
    let(:disabled_student) { create(:student, school: school, disabled: true, password: "correct horse") }
    let(:credentials) { {user: {login: disabled_student.username, password: "correct horse"}} }

    it "refuses a disabled user" do
      post user_session_path, params: credentials
      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("Your account is no longer active")
    end

    it "refuses a disabled user arriving through Wonde" do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:wonde] =
        OmniAuth::AuthHash.new(provider: "wonde", uid: disabled_student.upi, info: {upi: disabled_student.upi})
      get user_wonde_omniauth_callback_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "accepts a username in any case" do
      post user_session_path, params: {user: {login: student.username.upcase, password: student.password}}
      expect(response).to redirect_to(dashboard_path)
    end

    it "accepts an email address in any case" do
      post user_session_path, params: {user: {login: school_admin.email.upcase, password: school_admin.password}}
      expect(response).to redirect_to(dashboard_path)
    end

    it "refuses a login sent as an array" do
      post user_session_path, params: {user: {login: [student.username], password: student.password}}
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Invalid login or password")
    end
  end

  describe "an admin's failed sign-ins" do
    let(:right_password) { {admin: {email: super_admin.email, password: super_admin.password}} }
    let(:wrong_password) { {admin: {email: super_admin.email, password: "not the password"}} }

    context "with four in a row" do
      before { 4.times { post admin_session_path, params: wrong_password } }

      it "still accepts the right password" do
        post admin_session_path, params: right_password
        expect(response).to redirect_to(system_root_path)
      end
    end

    context "with five in a row" do
      before { 4.times { post admin_session_path, params: wrong_password } }

      it "emails unlock instructions" do
        expect { post admin_session_path, params: wrong_password }
          .to change(ActionMailer::Base.deliveries, :count).by(1)
        expect(ActionMailer::Base.deliveries.last).to have_attributes(to: [super_admin.email], subject: "Unlock instructions")
      end

      describe "the right password" do
        before { post admin_session_path, params: wrong_password }

        it "is refused with the same message as a wrong one" do
          post admin_session_path, params: right_password
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Invalid email or password")
        end

        it "is still refused 59 minutes later" do
          travel 59.minutes
          post admin_session_path, params: right_password
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "is accepted again an hour later" do
          travel 1.hour + 1.second
          post admin_session_path, params: right_password
          expect(response).to redirect_to(system_root_path)
        end
      end
    end
  end

  describe "Google" do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] =
        OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "123456123456", info: {email: "test@test.com"})
    end

    describe "signing in" do
      context "with a linked account" do
        let!(:google_student) { create(:student, school: school, oauth_uid: "123456123456") }

        it "signs the user in" do
          get user_google_oauth2_omniauth_callback_path
          expect(response).to redirect_to(dashboard_path)
        end
      end

      context "with no matching account" do
        it "refuses with an alert" do
          get user_google_oauth2_omniauth_callback_path
          expect(response).to redirect_to(root_path)
          follow_redirect!
          expect(response.body).to include("Your account has not been found")
        end
      end
    end

    describe "linking an account" do
      let(:unlinked_student) { create(:student, :no_oauth, school: school) }

      before do
        sign_in unlinked_student
        get user_google_oauth2_omniauth_callback_path
      end

      it "stores the Google identity" do
        expect(unlinked_student.reload)
          .to have_attributes(oauth_uid: "123456123456", oauth_email: "test@test.com", oauth_provider: "google_oauth2")
      end

      it "redirects to the dashboard with a confirmation" do
        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include("Successfully linked Google account")
      end
    end
  end

  describe "an existing session" do
    before do
      sign_in student
      get dashboard_path
      student.update!(disabled: true)
    end

    it "ends once the user is disabled" do
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "signing out" do
    before { sign_in student }

    it "disconnects the user's live leaderboard streams" do
      expect { delete destroy_user_session_path }
        .to have_broadcasted_to("action_cable/#{student.to_gid_param}").with(type: "disconnect", reconnect: false)
    end
  end
end
