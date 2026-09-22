# frozen_string_literal: true

require "rails_helper"

RSpec.describe SchoolPolicy, :default_creates do
  subject(:policy) { described_class.new(actor, school) }

  shared_examples "a permission of the school's own admins" do |permission|
    context "as a school admin of the school" do
      let(:actor) { school_admin }
      it { is_expected.to public_send(:"be_#{permission}") }
    end

    context "as a school admin of another school" do
      let(:actor) { create(:school_admin, school: create(:school)) }
      it { is_expected.not_to public_send(:"be_#{permission}") }
    end

    context "as a student" do
      let(:actor) { student }
      it { is_expected.not_to public_send(:"be_#{permission}") }
    end
  end

  describe "#show?" do
    include_examples "a permission of the school's own admins", :show
  end

  describe "#reset_all_passwords?" do
    include_examples "a permission of the school's own admins", :reset_all_passwords
  end

  describe "#sync?" do
    include_examples "a permission of the school's own admins", :sync
  end
end
