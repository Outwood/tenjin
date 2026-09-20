# frozen_string_literal: true

require "rails_helper"

# Which students and scores reach the table is pinned by
# spec/queries/leaderboard/query_spec.rb and spec/requests/leaderboard_request_spec.rb;
# these examples cover how Alpine renders what arrives.
RSpec.describe "User views the leaderboard", :default_creates, :js do
  let!(:topic_score) { create(:topic_score, topic: topic, user: student, score: 10) }

  before do
    setup_subject_database
    sign_in student
  end

  context "with the student's score on the leaderboard" do
    before { visit(leaderboard_path(quiz_subject.name)) }

    it "highlights the student's row" do
      expect(page).to have_css("tr#row-#{student.id}.current-user td#name-#{student.id}",
        exact_text: initialize_name(student))
    end
  end

  context "with 20 other students on the leaderboard" do
    before do
      (1..20).each { |n| create(:topic_score, topic: topic, school: school, score: n * 10) }
    end

    context "when the student is in the top ten" do
      let!(:topic_score) { create(:topic_score, topic: topic, user: student, score: 500) }

      before { visit(leaderboard_path(quiz_subject.name)) }

      it "shows the top ten" do
        expect(page).to have_css("#leaderboardTable tbody tr", count: 10)
          .and have_css("#leaderboardTable tbody tr:nth-child(1)#row-#{student.id} td:first-child", exact_text: "1")
          .and have_css("#leaderboardTable tbody tr:nth-child(10) td:first-child", exact_text: "10")
      end
    end

    context "when the student is mid-table" do
      let!(:topic_score) { create(:topic_score, topic: topic, user: student, score: 85) }

      before { visit(leaderboard_path(quiz_subject.name)) }

      it "shows the ten around the student" do
        expect(page).to have_css("#leaderboardTable tbody tr", count: 10)
          .and have_css("#leaderboardTable tbody tr:nth-child(1) td:first-child", exact_text: "9")
          .and have_css("#leaderboardTable tbody tr:nth-child(5)#row-#{student.id} td:first-child", exact_text: "13")
      end
    end

    context "when the student is at the bottom" do
      let!(:topic_score) { create(:topic_score, topic: topic, user: student, score: 0) }

      before { visit(leaderboard_path(quiz_subject.name)) }

      it "shows the bottom ten" do
        expect(page).to have_css("#leaderboardTable tbody tr", count: 10)
          .and have_css("#leaderboardTable tbody tr:nth-child(1) td:first-child", exact_text: "12")
          .and have_css("#leaderboardTable tbody tr:nth-child(10)#row-#{student.id} td:first-child", exact_text: "21")
          .and have_css("td#score-#{student.id}", exact_text: "0")
      end
    end
  end

  context "with an active leaderboard icon" do
    let(:blue_star) do
      create(:customisation, customisation_type: "leaderboard_icon", value: "blue,star", name: "Blue Star")
    end
    let!(:active_customisation) { create(:active_customisation, user: student, customisation: blue_star) }
    let!(:plain_score) { create(:topic_score, topic: topic, school: school, score: 20) }

    before { visit(leaderboard_path(quiz_subject.name)) }

    it "shows the icon in its colour, and none for a student without one" do
      expect(page).to have_css("td#icon-#{student.id} i.fa-star", style: "color: blue;")
        .and have_no_css("td#icon-#{plain_score.user_id} i")
    end
  end

  describe "weekly awards" do
    let(:one_win) { create(:topic_score, topic: topic, school: school, score: 20).user }
    let(:three_wins) { create(:topic_score, topic: topic, school: school, score: 30).user }
    let(:six_wins) { create(:topic_score, topic: topic, school: school, score: 40).user }

    before do
      create(:leaderboard_award, user: one_win, subject: quiz_subject, school: school)
      create_list(:leaderboard_award, 3, user: three_wins, subject: quiz_subject, school: school)
      create_list(:leaderboard_award, 6, user: six_wins, subject: quiz_subject, school: school)
      visit(leaderboard_path(quiz_subject.name))
    end

    it "stars each win in red, three in silver and five in gold" do
      expect(page).to have_css("td#awards-#{one_win.id} i.fa-star", style: "color: red;", count: 1)
        .and have_css("td#awards-#{three_wins.id} i.fa-star", style: "color: silver;", count: 1)
        .and have_css("td#awards-#{six_wins.id} i.fa-star", style: "color: gold;", count: 1)
        .and have_css("td#awards-#{six_wins.id} i.fa-star", style: "color: red;", count: 1)
        .and have_no_css("td#awards-#{student.id} i")
    end
  end

  describe "weekly winners" do
    let!(:classroom_winner) { create(:classroom_winner, user: student, classroom: classroom, score: 100) }

    before { visit(leaderboard_path(quiz_subject.name)) }

    it "shows last week's winner for the chosen classroom" do
      click_button("Select Class")
      click_button(classroom.name)
      expect(page).to have_content("#{classroom.name} winner: #{initialize_name(student)} - 100 points")
    end
  end
end
