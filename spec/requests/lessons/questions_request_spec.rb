# frozen_string_literal: true

require "rails_helper"

RSpec.describe "lesson questions controller", :default_creates do
  let(:lesson) { create(:lesson, topic: topic) }

  describe "GET /lessons/:lesson_id/questions" do
    describe "as a teacher" do
      let!(:question) { create(:question, lesson: lesson, topic: topic, question_text: "What do plants make in daylight?") }
      let!(:retired_question) do
        create(:question, lesson: lesson, topic: topic, question_text: "Which gas do leaves take in?", active: false)
      end

      let!(:teacher_enrollment) { create(:enrollment, user: teacher, classroom: classroom) }

      before do
        sign_in teacher
        get lesson_questions_path(lesson)
      end

      it "lists the lesson's active questions" do
        expect(Capybara.string(response.body)).to have_text("What do plants make in daylight?")
          .and have_no_text("Which gas do leaves take in?")
      end
    end

    describe "as a question author" do
      let(:author) { create(:question_author, subject: quiz_subject) }

      before do
        sign_in author
        get lesson_questions_path(lesson)
      end

      it "marks Lessons, not Questions, as the current section" do
        expect(Capybara.string(response.body))
          .to have_css("#navbar-main .nav-link.active[aria-current='page'][href='#{lessons_path}']", exact_text: "Lessons")
          .and have_no_css("#navbar-main .nav-link.active[href='#{questions_path}']")
      end
    end
  end
end
