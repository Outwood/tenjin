# frozen_string_literal: true

require "rails_helper"

# Server-rendered dashboard state (the challenge and homework tables, the nav
# bar's challenge points) is covered in spec/requests/dashboard_request_spec.rb.
# What stays is the quiz-starter wiring smoke: a row's data values reach the
# quiz create action and the page moves to the new quiz. The controller's
# lesson and no-lesson branches are in
# spec/javascript/controllers/quiz_starter_controller.test.js.
RSpec.describe "Student visits the dashboard", :default_creates, :js do
  before do
    setup_subject_database
    sign_in student
  end

  describe "a lesson homework row" do
    let(:lesson) { create(:lesson, topic: topic) }
    let!(:homework) { create(:homework, classroom: classroom, topic: topic, lesson: lesson) }
    let!(:lesson_questions) { create_list(:question, 10, lesson: lesson, topic: topic) }

    before { visit(dashboard_path) }

    it "opens a quiz named after the lesson when clicked" do
      find(".homework-row[data-homework='#{homework.id}']").click
      expect(page).to have_css("#quiz-name", exact_text: lesson.title)
    end
  end
end
