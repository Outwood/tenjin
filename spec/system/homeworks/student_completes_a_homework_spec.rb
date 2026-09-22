# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Student completes a homework", :default_creates, :js do
  let(:question) { create(:question, topic: topic) }

  before do
    setup_subject_database
    sign_in student
  end

  context "with a topic homework" do
    let!(:homework) { create(:homework, topic: topic, classroom: classroom, required: 10) }
    let!(:answer) { create(:answer, question: question, correct: true) }

    before { visit(dashboard_path) }

    # End-to-end smoke from the dashboard row through a quiz and back; the row's
    # quiz start is in quiz_starter_controller.test.js, the icons in dashboard_request_spec.rb
    it "shows a tick next to the homework row on completion" do
      find(".homework-row[data-homework='#{homework.id}']").click
      find(".question-button", match: :first).click
      find(".next-button", match: :first).click
      expect(page).to have_css(".homework-row[data-homework='#{homework.id}'] > td > i.fa-check")
    end
  end
end
