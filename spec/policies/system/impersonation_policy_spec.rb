# frozen_string_literal: true

require "rails_helper"

RSpec.describe System::ImpersonationPolicy do
  subject(:policy) { described_class.new(admin, :impersonation) }

  describe "#create?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.to be_create }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.to be_create }
    end
  end

  describe "#destroy?" do
    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.to be_destroy }
    end
  end
end
