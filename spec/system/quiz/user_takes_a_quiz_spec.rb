# frozen_string_literal: true

require "rails_helper"

# One wiring smoke per quiz controller. Their branches live in
# spec/javascript/controllers/ (multiple_choice_question, short_response_question,
# unfair_flag); the answer payload in spec/requests/quizzes_request_spec.rb and
# spec/serializers/quiz/answer_outcome_serializer_spec.rb, as does the
# server-rendered quiz state.
RSpec.describe "User takes a quiz", :default_creates, :js do
  before do
    setup_subject_database
    sign_in student
  end

  describe "a multiple choice question" do
    let!(:question) { create(:question, topic: topic) }
    let(:correct_answer) { question.answers.find_by!(correct: true) }

    before do
      create_list(:answer, 3, question: question, correct: false)
      navigate_to_quiz
    end

    it "marks the answer, updates the stats and moves on" do
      find("#response-#{correct_answer.id}").click
      expect(page).to have_css("#response-#{correct_answer.id}.correct-answer i.fa-check")
        .and have_css("#streak", exact_text: "1")

      find(".next-button").click
      expect(page).to have_content("Finished!")
    end
  end

  describe "a short answer question" do
    let!(:question) { create(:short_answer_question, topic: topic) }

    before do
      question.answers.find_by!(correct: true).update!(text: "Paris")
      navigate_to_quiz
    end

    it "checks the answer on Enter and updates the stats" do
      fill_in("shortAnswerText", with: "Paris").native.send_keys(:return)
      expect(page).to have_css("#shortAnswerButton.correct-answer i.fa-check")
        .and have_css("#answeredCorrect", exact_text: "1")
        .and have_css(".next-button")
    end
  end

  describe "the unfair flag" do
    let!(:question) { create(:question, topic: topic) }

    before { navigate_to_quiz }

    it "flags the question and thanks the student" do
      find("#unfairFlag").click
      expect(page).to have_css("#unfairFlag i.fas.fa-flag")
        .and have_content("You have flagged this question as unfair")
    end
  end
end
