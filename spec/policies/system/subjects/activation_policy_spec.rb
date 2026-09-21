# frozen_string_literal: true

require "rails_helper"

RSpec.describe System::Subjects::ActivationPolicy do
  subject(:policy) { described_class.new(admin, build_stubbed(:subject, active: active)) }

  describe "#destroy?" do
    context "when the subject is active" do
      let(:active) { true }

      context "as a super admin" do
        let(:admin) { build_stubbed(:super_admin) }

        it { is_expected.to be_destroy }
      end

      context "as a school group admin" do
        let(:admin) { build_stubbed(:school_group_admin) }

        it { is_expected.not_to be_destroy }
      end
    end

    context "when the subject is already deactivated" do
      let(:active) { false }
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.not_to be_destroy }
    end
  end

  describe "#create?" do
    let(:active) { false }

    context "as a super admin" do
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.to be_create }
    end

    context "as a school group admin" do
      let(:admin) { build_stubbed(:school_group_admin) }

      it { is_expected.not_to be_create }
    end

    context "when the subject is active" do
      let(:active) { true }
      let(:admin) { build_stubbed(:super_admin) }

      it { is_expected.not_to be_create }
    end
  end
end
