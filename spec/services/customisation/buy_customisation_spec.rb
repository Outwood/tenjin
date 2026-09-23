# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customisation::BuyCustomisation, :default_creates do
  let(:student) { create(:student, school: school, challenge_points: 10) }
  let(:customisation) { create(:dashboard_customisation, cost: 5) }
  let(:old_customisation) { create(:dashboard_customisation, cost: 2) }

  before do
    create(:customisation_unlock, customisation: old_customisation, user: student)
  end

  context "when buying a new dashboard style" do
    it "creates a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.to change(CustomisationUnlock, :count).by(1)
    end

    it "deducts the correct number of challenge points" do
      expect { described_class.call(user: student, customisation: customisation) }.to change { student.reload.challenge_points }.by(-5)
    end

    context "after purchase" do
      before { described_class.call(user: student, customisation: customisation) }

      it "sets the new customisation as active" do
        expect(ActiveCustomisation.where(customisation: customisation)).not_to be_empty
      end

      it "deactivates the old customisation" do
        expect(ActiveCustomisation.where(customisation: old_customisation)).to be_empty
      end
    end
  end

  context "when buying a leaderboard icon" do
    let(:customisation) { create(:customisation, cost: 5, customisation_type: "leaderboard_icon") }

    it "creates a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.to change(CustomisationUnlock, :count).by(1)
    end

    context "after purchase" do
      before { described_class.call(user: student, customisation: customisation) }

      it "sets the new icon as active" do
        expect(ActiveCustomisation.where(customisation: customisation)).not_to be_empty
      end

      it "deactivates the old icon" do
        expect(ActiveCustomisation.where(customisation: old_customisation)).to be_empty
      end
    end
  end

  context "when the student has no existing customisation" do
    before { CustomisationUnlock.destroy_all }

    it "creates a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.to change(CustomisationUnlock, :count).by(1)
    end
  end

  context "when the student does not have enough points" do
    let(:student) { create(:student, school: school, challenge_points: 3) }

    it "returns a failure result with the error message" do
      result = described_class.call(user: student, customisation: customisation)
      expect(result).to be_failure
      expect(result.error).to eq "You do not have enough points"
    end

    it "does not create a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change(CustomisationUnlock, :count)
    end
  end

  context "with no challenge points" do
    let(:student) { create(:student, school: school, challenge_points: nil) }

    it "returns a failure result with the error message" do
      result = described_class.call(user: student, customisation: customisation)
      expect(result).to be_failure
      expect(result.error).to eq "You do not have enough points"
    end
  end

  # Read the stored total without reloading the stale user the service is given
  def stored_points = User.find(student.id).challenge_points

  context "when points are awarded after the user was loaded" do
    before { User.where(id: student.id).update_all(challenge_points: 20) }

    it "deducts from the stored total" do
      expect { described_class.call(user: student, customisation: customisation) }
        .to change { stored_points }.from(20).to(15)
    end
  end

  context "when points are spent after the user was loaded" do
    before { User.where(id: student.id).update_all(challenge_points: 3) }

    it "returns a failure result with the error message" do
      result = described_class.call(user: student, customisation: customisation)
      expect(result).to be_failure
      expect(result.error).to eq "You do not have enough points"
    end

    it "does not create a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change(CustomisationUnlock, :count)
    end

    it "does not change the stored total" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change { stored_points }
    end
  end

  context "when the customisation is not purchasable" do
    let(:customisation) { create(:dashboard_customisation, cost: 5, purchasable: false) }

    it "returns a failure result with the error message" do
      result = described_class.call(user: student, customisation: customisation)
      expect(result).to be_failure
      expect(result.error).to eq "This customisation is not for sale"
    end

    it "does not create a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change(CustomisationUnlock, :count)
    end

    it "does not deduct any points" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change { student.reload.challenge_points }
    end
  end

  context "when the customisation is retired" do
    let(:customisation) { create(:dashboard_customisation, cost: 5, retired: true) }

    it "does not create a customisation unlock" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change(CustomisationUnlock, :count)
    end
  end

  context "when switching to an owned customisation that is no longer for sale" do
    let(:customisation) { create(:dashboard_customisation, cost: 5, retired: true) }

    before do
      create(:customisation_unlock, customisation: customisation, user: student)
      described_class.call(user: student, customisation: customisation)
    end

    it "sets the customisation as active" do
      expect(ActiveCustomisation.where(customisation: customisation)).not_to be_empty
    end
  end

  context "when the customisation is nil" do
    it "returns a failure result" do
      result = described_class.call(user: student, customisation: nil)
      expect(result).to be_failure
      expect(result.error).to eq "Customisation not found"
    end
  end

  context "when the user is nil" do
    it "returns a failure result" do
      result = described_class.call(user: nil, customisation: customisation)
      expect(result).to be_failure
      expect(result.error).to eq "User not found"
    end
  end

  context "when buying a previously purchased customisation" do
    before do
      create(:customisation_unlock, customisation: customisation, user: student)
    end

    it "does not deduct any points" do
      expect { described_class.call(user: student, customisation: customisation) }.not_to change { student.reload.challenge_points }
    end

    context "after re-activating" do
      before { described_class.call(user: student, customisation: customisation) }

      it "sets the customisation as active" do
        expect(ActiveCustomisation.where(customisation: customisation)).not_to be_empty
      end

      it "deactivates the previously active customisation" do
        expect(ActiveCustomisation.where(customisation: old_customisation)).to be_empty
      end
    end
  end
end
