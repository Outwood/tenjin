# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Author edits a question", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }
  let(:question) { create(:question, topic: topic) }

  before { sign_in author }

  describe "topic question index", :js do
    let!(:lesson) { create(:lesson, topic: topic, title: "Photosynthesis") }

    before { visit(topic_questions_path(topic)) }

    # auto-submit smokes; TopicsController#update is covered in spec/requests/topics_request_spec.rb
    it "saves the default lesson on change" do
      select "Photosynthesis", from: "Default lesson"
      expect(page).to have_css("[role=status]", exact_text: "Saved")
      visit(topic_questions_path(topic))
      expect(page).to have_select("Default lesson", selected: "Photosynthesis")
    end

    it "renames the page's heading once the name saves" do
      fill_in "Name", with: "Plant nutrition"
      find_field("Name").send_keys(:tab)
      expect(page).to have_css("h1", exact_text: "Plant nutrition")
        .and have_css(".breadcrumb-item.active", exact_text: "Plant nutrition")
    end
  end

  describe "question editor" do
    before { visit(edit_question_path(question)) }

    context "with a lesson for the topic" do
      let!(:lesson) { create(:lesson, topic: topic, title: "Photosynthesis") }

      before { visit(edit_question_path(question)) }

      # rack_test form-wiring smoke; the persisted state is covered in spec/requests/question_request_spec.rb
      it "assigns a lesson" do
        select "Photosynthesis", from: "Lesson"
        click_button("Save Question")
        expect(page).to have_css(".alert-info", text: "Question successfully updated")
      end
    end

    context "with a boolean question" do
      let(:question) { create(:boolean_question, topic: topic) }

      # rack_test form-wiring smoke; marking is covered in spec/requests/question_request_spec.rb
      it "chooses the correct answer" do
        find("#table-answers input[type=radio][value='False']").choose
        click_button("Save Question")
        expect(page).to have_css(".alert-info", text: "Question successfully updated")
          .and have_checked_field(type: :radio, with: "False")
      end
    end

    # turbo_confirm smoke; QuestionsController#destroy is covered in spec/requests/question_request_spec.rb
    it "deletes the question", :js do
      page.accept_confirm("Delete this question? Students will no longer be asked it.") { click_button("Delete Question") }
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
      click_button("Add Answer")
      find("#table-answers tbody tr:nth-of-type(2) .text-answer").set("Photosynthesis")
      click_button("Save Question")
      expect(page).to have_field(with: "Photosynthesis")
    end

    context "with an incorrect answer", :js do
      let!(:incorrect_answer) { create(:answer, question: question, correct: false) }

      before { visit(edit_question_path(question)) }

      # nested-fields#removeRecord smoke; the hiding is in
      # spec/javascript/controllers/nested_fields_controller.test.js, _destroy handling
      # in spec/requests/question_request_spec.rb
      it "removes an answer on save" do
        find("#table-answers tbody tr:last-of-type").click_button("Remove")
        click_button("Save Question")
        expect(page).to have_css(".alert-info", text: "Question successfully updated")
          .and have_css("#table-answers tbody tr", count: 1, visible: :all)
      end
    end
  end
end
