# frozen_string_literal: true

module Users
  # Unlinks the Google account a user signs in with.
  class OauthLinksController < ApplicationController
    before_action :authenticate_user!

    def destroy
      user = authorize User.find(params[:user_id]), :unlink_oauth_account?
      user.update(oauth_uid: "", oauth_email: "", oauth_provider: "")

      redirect_to user
    end
  end
end
