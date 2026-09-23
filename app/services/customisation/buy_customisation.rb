# frozen_string_literal: true

class Customisation::BuyCustomisation < ApplicationCommand
  def initialize(user:, customisation:)
    @user = user
    @customisation = customisation
  end

  def call
    return failure("Customisation not found") if @customisation.blank?
    return failure("User not found") if @user.blank?

    ApplicationRecord.transaction do
      # Serialises the user's purchases: a double submit finds the first one's
      # unlock, and two switches cannot leave two active items of one type
      User.lock.find(@user.id)
      buy_or_switch
    end
  end

  private

  def buy_or_switch
    unlock = CustomisationUnlock.where(customisation: @customisation, user: @user).first_or_initialize
    if unlock.new_record?
      return failure("This customisation is not for sale") unless @customisation.for_sale?
      return failure("You do not have enough points") unless deduct_challenge_points
    end

    destroy_old_active_customisation
    create_new_active_customisation
    unlock.save!
    success
  end

  # Spends against the stored total, not the one loaded with the request
  def deduct_challenge_points
    User.where(id: @user.id, challenge_points: @customisation.cost..)
      .update_all(["challenge_points = challenge_points - ?", @customisation.cost])
      .positive?
  end

  def destroy_old_active_customisation
    ActiveCustomisation.joins(:customisation)
      .where(customisations: {customisation_type: @customisation.customisation_type})
      .where(user: @user)
      .destroy_all
  end

  def create_new_active_customisation
    ActiveCustomisation.create(user: @user, customisation: @customisation)
  end
end
