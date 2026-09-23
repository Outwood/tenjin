# frozen_string_literal: true

module Customisations
  # Buys a customisation from the shop with the user's challenge points.
  class UnlocksController < ApplicationController
    before_action :authenticate_user!

    def create
      authorize current_user, :show?
      customisation = Customisation.find_by(id: params[:customisation_id])
      result = Customisation::BuyCustomisation.call(user: current_user, customisation: customisation)
      flash[:notice] = result_message(customisation, result)
      redirect_to dashboard_path
    end

    private

    def result_message(customisation, result)
      case result
      in {success: true}
        "Congratulations! You have bought #{customisation.name}"
      in {success: false, error:}
        error
      end
    end
  end
end
