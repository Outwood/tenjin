# frozen_string_literal: true

require "rails_helper"

RSpec.describe "lesson questions controller", :default_creates do
  let(:lesson) { create(:lesson, topic: topic) }

  describe "GET /lessons/:lesson_id/questions" do
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
end
