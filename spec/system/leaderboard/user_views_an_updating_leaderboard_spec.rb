# frozen_string_literal: true

require "rails_helper"

# Which school's broadcasts reach a viewer is pinned by spec/channels/leaderboard_channel_spec.rb
# and spec/services/leaderboard/broadcast_leaderboard_point_spec.rb; these examples cover what
# the table does with a broadcast it receives.
RSpec.describe "User views an updating leaderboard", :default_creates, :js do
  let!(:student_topic_score) { create(:topic_score, user: student, score: 10, topic: topic) }
  let!(:other_scores) { (1..9).map { |n| create(:topic_score, topic: topic, school: school, score: n) } }
  let(:another_student) { other_scores.first.user }

  before do
    setup_subject_database
    sign_in student
  end

  # A broadcast sent before the cable connects is lost, and a flash can only be
  # asserted absent once the table has rendered, so each context waits for both.
  context "when receiving updates" do
    before do
      visit(leaderboard_path(quiz_subject.name))
      expect(page).to have_css("#leaderboardTable tbody tr", count: 10).and have_css("#connected")
    end

    it "flashes each student whose score arrives" do
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      Leaderboard::BroadcastLeaderboardPoint.new(topic, another_student).call
      expect(page).to have_css("tr#row-#{student.id}.score-changed")
        .and have_css("tr#row-#{another_student.id}.score-changed")
    end

    # The flash lasts a second, so a longer wait would let it clear unseen.
    it "does not flash anyone when loaded" do
      expect(page).to have_no_css("tr.score-changed", wait: 0.5)
    end

    it "clears the flash after a second" do
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      expect(page).to have_css("tr#row-#{student.id}.score-changed")
      expect(page).to have_no_css("tr.score-changed", wait: 1.5)
    end

    context "when a new student's score arrives" do
      let(:new_entry) { create(:topic_score, topic: topic, school: school, score: 11) }

      it "re-ranks the table and keeps it to ten rows" do
        Leaderboard::BroadcastLeaderboardPoint.new(topic, new_entry.user).call
        expect(page).to have_css("#leaderboardTable tbody tr:nth-child(1)#row-#{new_entry.user_id} td#name-#{new_entry.user_id}",
          exact_text: initialize_name(new_entry.user))
          .and have_css("#leaderboardTable tbody tr:nth-child(2)#row-#{student.id}")
          .and have_css("#leaderboardTable tbody tr", count: 10)
      end
    end
  end

  context "with a school group" do
    let!(:second_school) { create(:school, school_group: school.school_group) }
    let!(:second_school_score) { create(:topic_score, topic: topic, school: second_school, score: 11) }

    before do
      visit(leaderboard_path(quiz_subject.name))
      expect(page).to have_css("#leaderboardTable tbody tr", count: 10).and have_css("#connected")
    end

    it "shows another school's update only once all schools are selected" do
      Leaderboard::BroadcastLeaderboardPoint.new(topic, second_school_score.user).call
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      expect(page).to have_css("tr#row-#{student.id}.score-changed")
        .and have_no_css("tr#row-#{second_school_score.user_id}")
      click_button("Select School")
      click_button("All")
      # Selecting "All" reloads the table from the server, and that reload
      # overwrites any flash a broadcast set before it landed. Wait for the
      # other school's row (score 11 keeps it inside the ten-row window)
      # so the broadcast arrives after the reload.
      expect(page).to have_css("tr#row-#{second_school_score.user_id}")
      Leaderboard::BroadcastLeaderboardPoint.new(topic, second_school_score.user).call
      expect(page).to have_css("tr#row-#{second_school_score.user_id}.score-changed")
    end
  end

  context "when viewing a single topic" do
    let(:different_topic) { create(:topic, subject: quiz_subject) }
    let!(:different_topic_score) { create(:topic_score, school: school, score: 11, topic: different_topic) }

    before do
      visit(leaderboard_path(quiz_subject.name, topic: topic))
      expect(page).to have_css("#leaderboardTable tbody tr", count: 10).and have_css("#connected")
    end

    it "flashes updates for the topic and ignores other topics" do
      Leaderboard::BroadcastLeaderboardPoint.new(different_topic, different_topic_score.user).call
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      expect(page).to have_css("tr#row-#{student.id}.score-changed")
        .and have_no_css("tr#row-#{different_topic_score.user_id}")
    end
  end
end
