# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Author adds a topic", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  before do
    sign_in author
    visit(questions_path)
  end

  # rack_test form-wiring smoke; Subjects::TopicsController is covered in spec/requests/subjects/topics_request_spec.rb
  it "lands on the named topic" do
    click_link "Add Topic"
    fill_in "Name", with: "Fractions"
    click_button "Create Topic"
    expect(page).to have_field("Topic Name:", with: "Fractions")
  end
end
