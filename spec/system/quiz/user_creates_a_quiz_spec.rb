# frozen_string_literal: true

require "rails_helper"

# Form-wiring smoke for the topic select. The refusal, cooldown and
# leaderboard assertions live in spec/requests/quizzes_request_spec.rb and
# spec/services/quiz/create_quiz_call_spec.rb; the dashboard's subject
# carousel in spec/requests/dashboard_request_spec.rb.
RSpec.describe "User creates a quiz", :default_creates do
  let!(:question) { create(:question, topic: topic) }

  before do
    setup_subject_database
    sign_in student
    visit(new_subject_quiz_path(quiz_subject))
  end

  it "starts a quiz on the chosen topic" do
    select topic.name, from: "quiz_topic_id"
    click_button("Create Quiz")
    expect(page).to have_css("#quiz-name", text: topic.name)
  end
end
