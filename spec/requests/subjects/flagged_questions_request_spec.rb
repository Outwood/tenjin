# frozen_string_literal: true

require "rails_helper"

RSpec.describe "subject flagged questions controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  describe "GET /subjects/:subject_id/flagged_questions" do
    let!(:flagged_question) { create(:question, topic: topic, flagged_questions_count: 5) }

    before do
      sign_in author
      get subject_flagged_questions_path(quiz_subject)
    end

    it "lists the subject's flagged questions" do
      expect(Capybara.string(response.body)).to have_css("#question-#{flagged_question.id}")
    end

    it "does not list unflagged questions"
  end
end
