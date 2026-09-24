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

  it "stores its text with whitespace collapsed, non-breaking spaces included" do
    expect(build(:answer, text: "\u00A0Max \u00A0 Jones\t").text).to eq("Max Jones")
  end

  describe "text within a question" do
    let(:question) { create(:question) }

    before { question.answers.first.update!(text: "Max Jones") }

    it "refuses a repeat" do
      expect {
        create(:answer, question: question, text: " Max  Jones ")
        check_deferred_constraints!
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "stores a repeat differing in case" do
      expect {
        create(:answer, question: question, text: "max jones")
        check_deferred_constraints!
      }.not_to raise_error
    end
  end

  describe "attempts that chose it" do
    let(:question) { create(:question) }
    let(:answer) { question.answers.first }
    let!(:asked_question) do
      create(:asked_question, :answered, question: question, answer: answer, response: {"text" => answer.text})
    end

    it "keeps them without the link when the answer is destroyed" do
      answer.destroy!
      expect(asked_question.reload).to have_attributes(answer_id: nil, response: {"text" => answer.text})
    end

    it "keeps them without the link when the answer is deleted in SQL" do
      Answer.where(id: answer.id).delete_all
      expect(asked_question.reload).to have_attributes(answer_id: nil, response: {"text" => answer.text})
    end
  end
end
