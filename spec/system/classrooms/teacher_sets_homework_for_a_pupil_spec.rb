# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teacher sets homework for a pupil", :default_creates do
  let!(:homework) { create(:homework, :overdue, classroom: classroom, topic: create(:topic, subject: quiz_subject, name: "Fractions")) }
  let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }

  before do
    sign_in teacher
    visit(new_classroom_pupil_homework_path(classroom, student))
  end

  # Wiring smoke for the homework checkboxes; what is set, and the refusals, are in
  # spec/requests/classrooms/pupils/homeworks_request_spec.rb
  it "sets the chosen homework" do
    check("Fractions")
    click_button("Set Homework")
    expect(page).to have_css(".alert-info", text: "Fractions homework set for #{student.forename} #{student.surname}")
  end
end
