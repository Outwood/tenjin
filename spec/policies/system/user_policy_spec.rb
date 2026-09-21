# frozen_string_literal: true

require "rails_helper"

RSpec.describe System::UserPolicy do
  subject(:policy) { described_class.new(admin, build_stubbed(:student)) }

  describe "#index?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.to be_index }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.to be_index }
    end
  end

  describe "#show?" do
    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.to be_show }
    end
  end

  describe "Scope" do
    subject(:resolved) { described_class::Scope.new(admin, User).resolve }

    let(:admin) { create(:school_group_admin) }
    let!(:listed) { create(:student) }

    it { is_expected.to include(listed) }
  end
end
