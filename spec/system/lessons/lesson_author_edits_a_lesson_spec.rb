# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lesson author edits a lesson", :default_creates do
  before do
    teacher.add_role :lesson_author, quiz_subject
    sign_in teacher
  end

  # Wiring smoke for the form's topic select; the persisted state, redirect
  # and invalid-submit branch live in spec/requests/lessons_request_spec.rb.
  describe "adding a lesson" do
    let!(:topic) { super() }

    before { visit(new_subject_lesson_path(quiz_subject)) }

    it "creates a lesson" do
      fill_in "URL", with: "https://vimeo.com/371104836"
      fill_in "Title", with: "Vimeo video lesson"
      select topic.name, from: "Topic"
      click_button("Create Lesson")
      expect(page).to have_css(".lesson-title", text: "Vimeo video lesson")
    end
  end

  # The one browser smoke for the turbo_confirm delete dialog; each
  # resource's destroy and redirect belong to its request spec
  # (spec/requests/lessons_request_spec.rb for lessons).
  describe "deleting a lesson", :js do
    let!(:lesson) { create(:lesson, topic: topic) }

    before { visit(lessons_path) }

    it "removes the lesson from the list" do
      find("summary", text: topic.name).click
      page.accept_confirm { click_button("Delete") }
      expect(page).to have_no_css(".lesson-title", text: lesson.title)
    end
  end
end
