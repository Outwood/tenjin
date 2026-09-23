# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Author adds a question", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  before do
    sign_in author
    visit(topic_questions_path(topic))
  end

  # rack_test form-wiring smoke: saving needs Trix and nested-fields, so this
  # submits the empty form; creation is covered in spec/requests/topics/questions_request_spec.rb
  it "submits the new question form to the topic" do
    click_link "Add Question"
    click_button "Save Question"
    expect(page).to have_css("p.error", text: "can't be blank")
  end
end
