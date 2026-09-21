# frozen_string_literal: true

require "rails_helper"

RSpec.describe System::Users::EmailPolicy do
  subject(:policy) { described_class.new(admin, user) }

  let(:user) { build_stubbed(:teacher) }

  describe "#update?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.to be_update }

      context "when the user is a student" do
        let(:user) { build_stubbed(:student) }

        it { is_expected.not_to be_update }
      end
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.not_to be_update }
    end
  end
end
