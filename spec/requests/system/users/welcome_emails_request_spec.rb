# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Users::WelcomeEmails", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "POST /system/users/:user_id/welcome_email" do
    it "enqueues the setup email to the user" do
      expect {
        post system_user_welcome_email_path(school_admin)
      }.to have_enqueued_mail(UserMailer, :setup_email).with(params: {user: school_admin}, args: [])
    end

    it "sends reset password instructions" do
      expect {
        post system_user_welcome_email_path(school_admin)
      }.to change { school_admin.reload.reset_password_token }
    end

    it "returns to the user with a confirmation" do
      post system_user_welcome_email_path(school_admin)

      expect(response).to redirect_to(system_user_path(school_admin))
      expect(flash[:notice]).to eq("Setup email sent to #{school_admin.full_name} (#{school_admin.email})")
    end
  end
end
