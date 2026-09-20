# frozen_string_literal: true

require "rails_helper"

RSpec.describe School::Statistics, :default_creates do
  let(:four_weeks_start) { 3.weeks.ago.to_date.beginning_of_week }

  context "with a school scope" do
    subject(:stats) { described_class.new(school) }

    let(:other_school_user) { create(:student, school: create(:school)) }

    describe "#asked_questions_last_four_weeks" do
      before do
        create(:user_statistic, user: student, questions_answered: 5, week_beginning: four_weeks_start)
        create(:user_statistic, user: other_school_user, questions_answered: 99, week_beginning: four_weeks_start)
      end

      it "sums questions answered by the school's users" do
        expect(stats.asked_questions_last_four_weeks).to eq 5
      end

      it "memoizes the result across calls" do
        stats.asked_questions_last_four_weeks
        expect(UserStatistic).not_to receive(:sum)
        stats.asked_questions_last_four_weeks
      end

      it "counts a week at the start of the four-week window" do
        other_student = create(:student, school: school)
        create(:user_statistic, user: other_student, questions_answered: 20, week_beginning: four_weeks_start)

        expect(stats.asked_questions_last_four_weeks).to eq 25
      end

      it "excludes a week before the four-week window" do
        create(:user_statistic, user: student, questions_answered: 20, week_beginning: four_weeks_start - 1.week)

        expect(stats.asked_questions_last_four_weeks).to eq 5
      end
    end

    describe "#asked_questions_weekly" do
      before do
        create(:user_statistic,
          user: student,
          questions_answered: 3,
          week_beginning: Date.current.beginning_of_week)
        create(:user_statistic,
          user: student,
          questions_answered: 10,
          week_beginning: 2.weeks.ago.beginning_of_week)
      end

      it "sums only this week's questions for the school" do
        expect(stats.asked_questions_weekly).to eq 3
      end
    end

    describe "#homeworks_completed_last_four_weeks" do
      context "with completed homeworks in and outside the school" do
        before do
          create(:homework_progress, user: student, completed: true)
          create(:homework_progress, user: other_school_user, completed: true)
        end

        it "counts only the school's completed homeworks" do
          expect(stats.homeworks_completed_last_four_weeks).to eq 1
        end
      end

      context "with an incomplete homework" do
        before { create(:homework_progress, user: student, completed: false) }

        it "excludes it from the count" do
          expect(stats.homeworks_completed_last_four_weeks).to eq 0
        end
      end

      it "counts a homework updated at the start of the four-week window" do
        create(:homework_progress, user: student, completed: true, updated_at: four_weeks_start)

        expect(stats.homeworks_completed_last_four_weeks).to eq 1
      end

      it "excludes a homework updated before the four-week window" do
        create(:homework_progress, user: student, completed: true, updated_at: four_weeks_start - 1.second)

        expect(stats.homeworks_completed_last_four_weeks).to eq 0
      end
    end

    describe "#homeworks_completed_weekly" do
      before do
        create(:homework_progress, user: student, completed: true, updated_at: Time.current)
        create(:homework_progress, user: student, completed: true, updated_at: 2.weeks.ago)
      end

      it "counts completed homeworks updated this week" do
        expect(stats.homeworks_completed_weekly).to eq 1
      end
    end

    describe "#customisation_unlocks_last_four_weeks" do
      before do
        create(:customisation_unlock, user: student)
        create(:customisation_unlock, user: other_school_user)
      end

      it "counts unlocks for the school's users" do
        expect(stats.customisation_unlocks_last_four_weeks).to eq 1
      end

      it "counts an unlock updated at the start of the four-week window" do
        create(:customisation_unlock, user: student, updated_at: four_weeks_start)

        expect(stats.customisation_unlocks_last_four_weeks).to eq 2
      end

      it "excludes an unlock updated before the four-week window" do
        create(:customisation_unlock, user: student, updated_at: four_weeks_start - 1.second)

        expect(stats.customisation_unlocks_last_four_weeks).to eq 1
      end
    end

    describe "#customisation_unlocks_weekly" do
      before do
        create(:customisation_unlock, user: student, updated_at: Time.current)
        create(:customisation_unlock, user: student, updated_at: 2.weeks.ago)
      end

      it "counts unlocks updated this week" do
        expect(stats.customisation_unlocks_weekly).to eq 1
      end
    end
  end

  context "without a school scope" do
    subject(:stats) { described_class.new }

    describe "#asked_questions_last_four_weeks" do
      before do
        create(:user_statistic, questions_answered: 10, week_beginning: four_weeks_start)
        create(:user_statistic, questions_answered: 7, week_beginning: four_weeks_start)
      end

      it "sums questions across all schools" do
        expect(stats.asked_questions_last_four_weeks).to eq 17
      end
    end

    describe "#homeworks_completed_last_four_weeks" do
      before do
        create(:homework_progress, completed: true)
        create(:homework_progress, completed: true)
      end

      it "counts homeworks across all schools" do
        expect(stats.homeworks_completed_last_four_weeks).to eq 2
      end
    end

    describe "#customisation_unlocks_last_four_weeks" do
      before do
        create(:customisation_unlock)
        create(:customisation_unlock)
      end

      it "counts customisation unlocks across all schools" do
        expect(stats.customisation_unlocks_last_four_weeks).to eq 2
      end
    end
  end
end
