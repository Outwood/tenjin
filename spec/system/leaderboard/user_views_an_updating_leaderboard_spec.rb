# frozen_string_literal: true

require "rails_helper"

# Wiring smoke for the live leaderboard, on a topic page so the topicId the view
# serialises has to satisfy the received guard: the JSON load renders the rows, a
# cable broadcast flashes one, and the school filter refetches the group. The
# component's branches are in spec/javascript/lib/live_leaderboard.test.js; which
# stream a broadcast reaches is in spec/channels/leaderboard_channel_spec.rb and
# spec/services/leaderboard/broadcast_leaderboard_point_spec.rb.
RSpec.describe "User views an updating leaderboard", :default_creates, :js do
  let!(:student_topic_score) { create(:topic_score, user: student, score: 10, topic: topic) }
  let(:second_school) { create(:school, name: "Rival High", school_group: school.school_group) }
  let!(:second_school_score) { create(:topic_score, topic: topic, school: second_school, score: 11) }

  before do
    sign_in student
    visit(topic_leaderboard_path(topic))
    # A broadcast sent before the cable connects is lost, and the flash needs the row it lands on
    expect(page).to have_css("tr#row-#{student.id}").and have_css("#connected")
  end

  it "flashes a broadcast score and refetches the group when all schools are selected" do
    Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
    expect(page).to have_css("tr#row-#{student.id}.score-changed td#score-#{student.id}", exact_text: "10")
    click_button("Select School")
    click_button("All")
    expect(page).to have_css("td#score-#{second_school_score.user_id}", exact_text: "11")
  end
end
