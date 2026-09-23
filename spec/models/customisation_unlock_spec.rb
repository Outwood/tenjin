# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomisationUnlock do
  it "has a valid factory" do
    expect(build(:customisation_unlock)).to be_valid
  end

  it "refuses a second unlock of a customisation for the same user" do
    unlock = create(:customisation_unlock)

    expect { create(:customisation_unlock, customisation: unlock.customisation, user: unlock.user) }
      .to raise_error(ActiveRecord::RecordNotUnique, /index_customisation_unlocks_on_user_id_and_customisation_id/)
  end

  describe "validations" do
    it { is_expected.to belong_to(:customisation) }
    it { is_expected.to belong_to(:user) }
  end
end
