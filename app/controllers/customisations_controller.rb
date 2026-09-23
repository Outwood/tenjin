# frozen_string_literal: true

class CustomisationsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize current_user, :show? # make it so that it checks if the school is permitted?
    # The shop offers every purchasable style to every user
    skip_policy_scope
    @subjects = current_user.subjects
    @bought_customisations = CustomisationUnlock.where(user: current_user).pluck(:customisation_id)
    @purchased_styles = Customisation.preload_image.where(id: @bought_customisations)
    @available_styles = Customisation.preload_image.where(purchasable: true)
      .where.not(id: @bought_customisations)
      .order(Arel.sql("RANDOM()"))
  end
end
