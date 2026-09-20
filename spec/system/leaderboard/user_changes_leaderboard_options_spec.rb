# frozen_string_literal: true

require "rails_helper"

# The filter options and the scores each request returns are pinned by
# spec/requests/leaderboard_request_spec.rb and spec/queries/leaderboard/query_spec.rb;
# these examples cover the Alpine filters and toggles.
RSpec.describe "User changes leaderboard options", :default_creates, :js do
  let!(:weekly_topic_score) { create(:topic_score, topic: topic, user: student, score: 30) }

  before do
    setup_subject_database
    sign_in student
  end

  context "with no school group" do
    before do
      school.update!(school_group: nil)
      visit(leaderboard_path(quiz_subject.name))
    end

    it "hides the school filter" do
      expect(page).to have_button("Select Class").and have_no_button("Select School")
    end
  end

  context "with a school group" do
    let(:second_school) { create(:school, school_group: school.school_group) }
    let!(:second_school_score) { create(:topic_score, school: second_school, topic: topic) }

    before { visit(leaderboard_path(quiz_subject.name)) }

    it "widens to the school group and narrows back to the school" do
      expect(page).to have_css("#leaderboardTable tbody tr", count: 1)
      click_button("Select School")
      click_button("All")
      expect(page).to have_css("#leaderboardTable tbody tr", count: 2)
      click_button("All")
      click_button(school.name)
      expect(page).to have_css("#leaderboardTable tbody tr", count: 1)
    end
  end

  context "with more than ten entries" do
    before do
      create_list(:topic_score, 11, school: school, topic: topic)
      visit(leaderboard_path(quiz_subject.name))
    end

    it "shows every entry only while show all is on" do
      expect(page).to have_css("#leaderboardTable tbody tr", count: 10)
      find("#showAll label").click
      expect(page).to have_css("#leaderboardTable tbody tr", count: 12)
      find("#showAll label").click
      expect(page).to have_css("#leaderboardTable tbody tr", count: 10)
    end
  end

  context "with an all time score" do
    let!(:all_time_score) { create(:all_time_topic_score, user: student, topic: topic, score: 500) }

    before { visit(leaderboard_path(quiz_subject.name)) }

    it "adds it to the weekly score while all time is on" do
      expect(page).to have_css("td#score-#{student.id}", exact_text: "30")
      find("#allTime label").click
      expect(page).to have_css("td#score-#{student.id}", exact_text: "530")
    end

    context "when the student has no weekly score" do
      let!(:weekly_topic_score) { nil }
      let!(:weekly_only_score) { create(:topic_score, topic: topic, school: school, score: 40) }

      before { visit(leaderboard_path(quiz_subject.name)) }

      it "lists all time-only and weekly-only students together" do
        expect(page).to have_css("tr#row-#{weekly_only_score.user_id}").and have_no_css("tr#row-#{student.id}")
        find("#allTime label").click
        expect(page).to have_css("td#score-#{student.id}", exact_text: "500")
          .and have_css("td#score-#{weekly_only_score.user_id}", exact_text: "40")
      end
    end
  end

  context "with a student in another classroom" do
    let(:second_classroom) { create(:classroom, subject: quiz_subject, school: school) }
    let(:second_student) { create(:student, school: school) }
    let!(:second_classroom_enrollment) { create(:enrollment, classroom: second_classroom, user: second_student) }
    let!(:second_classroom_topic_score) { create(:topic_score, user: second_student, topic: topic) }

    before { visit(leaderboard_path(quiz_subject.name)) }

    it "narrows the table to the chosen classroom" do
      expect(page).to have_css("#leaderboardTable tbody tr", count: 2)
      click_button("Select Class")
      click_button(second_classroom.name)
      expect(page).to have_css("#leaderboardTable tbody tr", count: 1).and have_css("tr#row-#{second_student.id}")
    end

    context "with a school group" do
      let!(:second_school) { create(:school, name: "Rival High", school_group: school.school_group) }

      before { visit(leaderboard_path(quiz_subject.name)) }

      it "clears the school filter when a classroom is chosen" do
        click_button("Select School")
        click_button("Rival High")
        expect(page).to have_button("Rival High")
        click_button("Select Class")
        click_button(second_classroom.name)
        expect(page).to have_button("Select School")
      end
    end
  end
end
