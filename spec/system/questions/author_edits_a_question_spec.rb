# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Author edits a question", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }
  let(:question) { create(:question, topic: topic) }

  before { sign_in author }

  describe "topic question index", :js do
    let!(:lesson) { create(:lesson, topic: topic, title: "Photosynthesis") }

    before { visit(topic_questions_path(topic)) }

    # auto-submit smoke; TopicsController#update is covered in spec/requests/topics_request_spec.rb
    it "saves the default lesson on change" do
      select "Photosynthesis", from: "Select Default Lesson"
      visit(topic_questions_path(topic))
      expect(page).to have_select("Select Default Lesson", selected: "Photosynthesis")
    end
  end

  describe "question editor" do
    before { visit(question_path(question)) }

    context "with a lesson for the topic" do
      let!(:lesson) { create(:lesson, topic: topic, title: "Photosynthesis") }

      before { visit(question_path(question)) }

      # rack_test form-wiring smoke; the persisted state is covered in spec/requests/question_request_spec.rb
      it "assigns a lesson" do
        select "Photosynthesis", from: "Lesson:"
        click_button("Save Question")
        expect(page).to have_css(".alert-info", text: "Question successfully updated")
      end
    end

    # turbo_confirm smoke; QuestionsController#destroy is covered in spec/requests/question_request_spec.rb
    it "deletes the question", :js do
      page.accept_confirm { click_button("Delete Question") }
      expect(page).to have_current_path(topic_questions_path(topic))
    end

    # reload-form smoke; the boolean preview is covered in spec/requests/question_request_spec.rb
    it "switches to boolean answers", :js do
      select "Boolean", from: "Question Type"
      expect(page).to have_field("answer-text-0", with: "False", readonly: true)
        .and have_field("answer-text-1", with: "True", readonly: true)
    end

    # nested-fields#add smoke; the row template and its keying are in
    # spec/javascript/controllers/nested_fields_controller.test.js, answers_attributes
    # handling in spec/requests/question_request_spec.rb
    it "adds an answer", :js do
      click_link("Add Answer")
      find("#table-answers tbody tr:nth-of-type(2) .text-answer").set("Photosynthesis")
      click_button("Save Question")
      expect(page).to have_field(with: "Photosynthesis")
    end

    context "with an incorrect answer", :js do
      let!(:incorrect_answer) { create(:answer, question: question, correct: false) }

      before { visit(question_path(question)) }

      # nested-fields#removeRecord smoke; _destroy handling is covered in spec/requests/question_request_spec.rb
      it "removes an answer" do
        expect(page).to have_css("#table-answers tbody tr", count: 2)
        find("#table-answers tbody tr:last-of-type .btn-danger").click
        expect(page).to have_css("#table-answers tbody tr", count: 1)
      end
    end
  end
end
