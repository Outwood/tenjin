# frozen_string_literal: true

require "rails_helper"

# The subject list and its links are pinned by spec/requests/leaderboard_request_spec.rb;
# this exercises the Bootstrap collapse and the Alpine-rendered heading.
RSpec.describe "User selects a leaderboard", :default_creates, :js do
  before do
    setup_subject_database
    sign_in student
  end

  context "with a topic in the subject" do
    let!(:topic) { super() }

    before { visit leaderboard_index_path }

    it "opens the subject and shows the chosen topic's leaderboard" do
      click_link(quiz_subject.name)
      within(".collapse.show") { click_link(topic.name) }
      expect(page).to have_css("h1", text: topic.name)
    end
  end
end
