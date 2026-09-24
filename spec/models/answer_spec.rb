# frozen_string_literal: true

require "rails_helper"

RSpec.describe Answer do
  it "has a valid factory" do
    expect(build(:answer)).to be_valid
  end

  describe "validations" do
    subject { build(:answer) }

    it { is_expected.to validate_presence_of(:text) }
  end

  describe "text within a question" do
    let(:question) { create(:question) }

    # The uniqueness constraint is checked at commit, which a transactional example never reaches
    let(:check_constraints) { -> { described_class.connection.execute("SET CONSTRAINTS ALL IMMEDIATE") } }

    before { question.answers.first.update!(text: "Max Jones") }

    it "refuses a repeat differing only in spacing" do
      expect {
        create(:answer, question: question, text: " Max  Jones ")
        check_constraints.call
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "stores a repeat differing in case" do
      expect {
        create(:answer, question: question, text: "max jones")
        check_constraints.call
      }.not_to raise_error
    end
  end
end
