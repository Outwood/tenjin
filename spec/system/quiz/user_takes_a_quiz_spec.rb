# frozen_string_literal: true

require "rails_helper"

# Server-rendered quiz state (lesson panel, rich-text images, flag icon,
# leaderboard warning, persisted stats) is covered in
# spec/requests/quizzes_request_spec.rb; only browser behaviour stays here.
RSpec.describe "User takes a quiz", :default_creates, :js do
  describe "a multiple choice question" do
    let(:correct_answer_text) { "Right answer" }
    let(:incorrect_answer_text) { "Wrong answer" }
    let!(:question) { create(:question, topic: topic) }

    before do
      setup_subject_database
      question.answers.find_by!(correct: true).update!(text: correct_answer_text)
      create(:answer, question: question, correct: false, text: incorrect_answer_text)
      create_list(:answer, 2, question: question, correct: false)
      sign_in student
      navigate_to_quiz
    end

    it "hides the next question button" do
      expect(page).to have_css(".next-button", visible: :hidden)
    end

    context "when an answer has been chosen" do
      before { find("button.question-button:first-of-type").click }

      it "reveals the next question button" do
        expect(page).to have_css(".next-button")
      end

      it "disables all answer buttons" do
        expect(page).to have_css(".question-button[disabled]", count: 4)
      end
    end

    context "when the chosen answer is correct" do
      before { find("button", text: correct_answer_text).click }

      it "marks the chosen answer correct with a check icon" do
        expect(page).to have_css("button.correct-answer", text: correct_answer_text)
          .and have_css("button.correct-answer i.fa-check")
      end
    end

    context "when the chosen answer is incorrect" do
      before { find("button", text: incorrect_answer_text).click }

      it "marks the guess wrong and highlights the correct answer" do
        expect(page).to have_css("button.incorrect-answer", text: incorrect_answer_text)
          .and have_css("button.incorrect-answer i.fa-times")
          .and have_css("button.correct-answer", text: correct_answer_text)
      end
    end

    describe "the unfair flag" do
      it "flags the question" do
        find("i.fa-flag").click
        expect(page).to have_css("i.fas.fa-flag").and have_content("You have flagged this question as unfair")
      end

      context "when the question has already been flagged" do
        let!(:flagged_question) { create(:flagged_question, user: student, question: question) }

        before { page.refresh }

        it "unflags the question" do
          find("i.fas.fa-flag").click
          expect(page).to have_css("i.far.fa-flag")
        end
      end
    end
  end

  context "with multiple questions" do
    let!(:question) { create(:question, topic: topic) }
    let!(:second_question) { create(:question, topic: topic) }

    before do
      setup_subject_database
      sign_in student
      navigate_to_quiz
    end

    it "allows the user to advance through each question" do
      find("button.question-button:first-of-type").click
      find(".next-button").click
      find("button.question-button:first-of-type").click
      find(".next-button").click
      expect(page).to have_content("Finished!")
    end
  end

  describe "a short answer question" do
    let(:correct_answer_text) { "Paris" }
    let(:incorrect_response) { "London" }
    let!(:question) { create(:short_answer_question, topic: topic) }

    before do
      setup_subject_database
      question.answers.find_by!(correct: true).update!(text: correct_answer_text)
      sign_in student
      navigate_to_quiz
    end

    context "when answering correctly" do
      let!(:doubling_multiplier) { create(:multiplier, score: 1, multiplier: 2) }

      before { fill_in("shortAnswerText", with: correct_answer_text).native.send_keys(:return) }

      it "marks the answer correct and reveals the next question button" do
        expect(page).to have_css("#shortAnswerButton.correct-answer i.fa-check")
          .and have_css(".next-button")
      end

      it "updates the streak, correct count and multiplier" do
        expect(page).to have_css("#streak", exact_text: "1")
          .and have_css("#answeredCorrect", exact_text: "1")
          .and have_css("#multiplier", exact_text: "2")
      end
    end

    context "when answering incorrectly" do
      before { fill_in("shortAnswerText", with: incorrect_response).native.send_keys(:return) }

      it "marks the answer wrong and reveals the correct answer" do
        expect(page).to have_css("#shortAnswerButton.incorrect-answer i.fa-times")
          .and have_field("shortAnswerText", disabled: true, with: correct_answer_text)
      end
    end

    context "with multiple correct answers" do
      let!(:second_correct_answer) { create(:answer, question: question, correct: true, text: "Lutetia") }

      before { fill_in("shortAnswerText", with: incorrect_response).native.send_keys(:return) }

      it "reveals every correct answer when the response is wrong" do
        expect(page).to have_field("shortAnswerText", disabled: true, with: /\A(Paris or Lutetia|Lutetia or Paris)\z/)
      end
    end
  end
end
