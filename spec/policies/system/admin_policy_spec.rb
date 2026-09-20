# frozen_string_literal: true

require "rails_helper"

RSpec.describe System::AdminPolicy do
  subject(:policy) { described_class.new(admin, admin) }

  describe "#index?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }
      it { is_expected.to be_index }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }
      it { is_expected.not_to be_index }
    end
  end

  describe "#new?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }
      it { is_expected.to be_new }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }
      it { is_expected.not_to be_new }
    end
  end

  describe "#manage_roles?" do
    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }
      it { is_expected.to be_manage_roles }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }
      it { is_expected.not_to be_manage_roles }
    end
  end

  describe "Scope" do
    subject(:resolved) { described_class::Scope.new(admin, Admin).resolve }

    let!(:other_admin) { create(:school_group_admin) }

    context "as a super admin" do
      let(:admin) { create(:super_admin) }

      it { is_expected.to include(other_admin) }
    end

    context "as a school group admin" do
      let(:admin) { create(:school_group_admin) }

      it { is_expected.to be_empty }
    end
  end
end
