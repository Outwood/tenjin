# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teacher sets homework", :default_creates, :js do
  let!(:lesson) { create(:lesson, topic: topic, questions_count: 10) }
  let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }

  before do
    sign_in teacher
    visit(new_homework_path(classroom: {classroom_id: classroom.id}))
  end

  # Wiring smoke for the date picker and the Stimulus lesson picker; lesson
  # filtering is in homework_controller.test.js, the saved homework in homeworks_request_spec.rb
  it "sets a lesson homework" do
    create_homework_for_lesson
    click_button("Set Homework")
    expect(page).to have_css(".alert-info", text: "#{lesson.title} homework set")
  end
end
