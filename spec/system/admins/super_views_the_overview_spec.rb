# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Super views the overview", :default_creates, :js do
  let(:two_weeks_ago) { (Date.current - 2.weeks).beginning_of_week }
  let(:this_week) { Date.current.beginning_of_week }
  let(:four_weeks_start) { 3.weeks.ago.to_date.beginning_of_week }
  let(:other_school) { create(:school) }
  let(:other_school_student) { create(:student, school: other_school) }

  before { sign_in super_admin }

  describe "viewing asked questions" do
    let!(:new_stat) { create(:user_statistic, user: student, week_beginning: this_week) }
    let!(:old_stat) { create(:user_statistic, user: student, week_beginning: two_weeks_ago) }
    let!(:new_stat_other_school) { create(:user_statistic, user: other_school_student, week_beginning: this_week) }
    let!(:old_stat_other_school) { create(:user_statistic, user: other_school_student, week_beginning: two_weeks_ago) }

    let(:four_week_answered) { UserStatistic.where(week_beginning: four_weeks_start..).sum(:questions_answered) }
    let(:weekly_answered) { UserStatistic.where(week_beginning: this_week).sum(:questions_answered) }

    before { visit(system_root_path) }

    it "shows questions answered in the last four weeks" do
      expect(page).to have_css("#asked_questions_last_four_weeks", exact_text: four_week_answered.to_fs(:delimited))
    end

    it "shows this week's questions answered" do
      expect(page).to have_css("#asked_questions_weekly", exact_text: weekly_answered.to_fs(:delimited))
    end
  end

  describe "viewing completed homework" do
    before do
      create(:homework_progress, user: student, completed: true, updated_at: this_week)
      create(:homework_progress, user: student, completed: true, updated_at: two_weeks_ago)
      create(:homework_progress, user: other_school_student, completed: true, updated_at: this_week)
      create(:homework_progress, user: other_school_student, completed: true, updated_at: two_weeks_ago)
      visit(system_root_path)
    end

    it "shows homeworks completed in the last four weeks" do
      expect(page).to have_css("#homeworks_completed_last_four_weeks",
        exact_text: HomeworkProgress.where(completed: true, updated_at: four_weeks_start..).count.to_s)
    end

    it "shows this week's completed homeworks" do
      expect(page).to have_css("#homeworks_completed_weekly",
        exact_text: HomeworkProgress.where(completed: true, updated_at: this_week..).count.to_s)
    end
  end
end
