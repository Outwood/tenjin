# frozen_string_literal: true

require "rails_helper"

# Who is offered the live toggle is pinned by spec/requests/leaderboard_request_spec.rb;
# these examples cover what the table does once it is on.
RSpec.describe "User views a live leaderboard", :default_creates, :js do
  let!(:student_topic_score) { create(:topic_score, user: student, score: 10, topic: topic) }

  before do
    setup_subject_database
    create(:topic_score, topic: topic, school: school, score: 5)
    sign_in teacher
  end

  # A broadcast sent before the cable connects is lost, and the live delta is
  # taken from the scores loaded before the toggle, so each context waits for both.
  context "when switched on" do
    before do
      visit(leaderboard_path(quiz_subject.name))
      expect(page).to have_css("tr#row-#{student.id}").and have_css("#connected")
      find("#toggleLive label").click
    end

    it "clears the table until it is switched off" do
      expect(page).to have_no_css("#leaderboardTable tbody tr")
      find("#toggleLive label").click
      expect(page).to have_css("#leaderboardTable tbody tr", count: 2)
    end

    context "when a student then scores" do
      before { student_topic_score.update!(score: 510) }

      it "shows the points scored since it was switched on" do
        Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
        expect(page).to have_css("tr#row-#{student.id}.score-changed td#score-#{student.id}", exact_text: "500")
      end
    end
  end

  context "with a school group" do
    let(:second_school) { create(:school, name: "Rival High", school_group: school.school_group) }
    let(:second_student) { create(:student, school: second_school) }
    let!(:second_school_score) { create(:topic_score, topic: topic, user: second_student, score: 100) }

    before do
      visit(leaderboard_path(quiz_subject.name))
      expect(page).to have_css("tr#row-#{student.id}").and have_css("#connected")
      find("#toggleLive label").click
    end

    it "shows updates from across the group and filters them by school" do
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      Leaderboard::BroadcastLeaderboardPoint.new(topic, second_student).call
      expect(page).to have_css("tr#row-#{student.id}").and have_css("tr#row-#{second_student.id}")
      click_button("All")
      click_button("Rival High")
      expect(page).to have_css("#leaderboardTable tbody tr", count: 1).and have_css("tr#row-#{second_student.id}")
    end
  end

  context "with a classmate in another classroom" do
    let(:second_classroom) { create(:classroom, subject: quiz_subject, school: school) }
    let(:classmate) { create(:student, school: school) }
    let!(:classmate_enrollment) { create(:enrollment, user: classmate, classroom: second_classroom) }
    let!(:classmate_score) { create(:topic_score, topic: topic, user: classmate, score: 20) }

    before do
      visit(leaderboard_path(quiz_subject.name))
      expect(page).to have_css("tr#row-#{student.id}").and have_css("#connected")
      find("#toggleLive label").click
    end

    it "filters updates by class" do
      click_button("Select Class")
      click_button(second_classroom.name)
      Leaderboard::BroadcastLeaderboardPoint.new(topic, student).call
      Leaderboard::BroadcastLeaderboardPoint.new(topic, classmate).call
      expect(page).to have_css("tr#row-#{classmate.id}.score-changed")
        .and have_css("#leaderboardTable tbody tr", count: 1)
    end
  end
end
