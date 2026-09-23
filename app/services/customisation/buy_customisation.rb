# frozen_string_literal: true

class Customisation::BuyCustomisation < ApplicationCommand
  def initialize(user:, customisation:)
    @user = user
    @customisation = customisation
  end

  def call
    return failure("Customisation not found") if @customisation.blank?
    return failure("User not found") if @user.blank?

    unlock = CustomisationUnlock.where(customisation: @customisation, user: @user).first_or_initialize
    if unlock.new_record?
      return failure("This customisation is not for sale") unless @customisation.for_sale?

      unlock.user = @user
    end

    bought = ApplicationRecord.transaction do
      raise ActiveRecord::Rollback unless unlock.persisted? || deduct_challenge_points
      destroy_old_active_customisation
      create_new_active_customisation
      unlock.save!
    end
    return failure("You do not have enough points") unless bought

    success
  end

  private

  # Spends the points in SQL against the stored total, so an award landing
  # mid-purchase survives and two purchases cannot overdraw
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
