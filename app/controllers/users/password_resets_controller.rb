# frozen_string_literal: true

module Users
  # Gives a user a new random password and hands it back to read out.
  class PasswordResetsController < ApplicationController
    before_action :authenticate_user!

    def create
      user = authorize User.find(params[:user_id]), :reset_password?
      new_password = Devise.friendly_token(6)

      if user.reset_password(new_password, new_password)
        render json: {id: user.id, password: new_password}
      else
        render json: {errors: user.errors.full_messages}, status: :unprocessable_content
      end
    end
  end
end
