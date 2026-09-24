# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quiz::CountAnswer, :default_creates do
  subject(:count) do
    described_class.call(question_id: question.id, user_id: student.id, correct: verdict, answered_at: answered_at)
  end

  let(:question) { create(:question, topic: topic) }
  let(:verdict) { true }
  let(:answered_at) { Time.current }

  def counts
    QuestionStatistic.find_by!(question: question).attributes.values_at("number_asked", "number_correct")
  end

  describe "the question's statistics" do
    context "with a question never answered before" do
      it "starts them at this answer" do
        count
        expect(counts).to eq [1, 1]
      end
    end

    context "with a question answered before" do
      before { create(:question_statistic, question: question, number_asked: 10, number_correct: 4) }

      it "adds one asked and one correct for a correct answer" do
        expect { count }.to change { counts }.from([10, 4]).to([11, 5])
      end

      context "with a wrong answer" do
        let(:verdict) { false }

        it "adds one asked and none correct" do
          expect { count }.to change { counts }.from([10, 4]).to([11, 4])
        end
      end

      context "with no verdict" do
        let(:verdict) { nil }

        it "adds one asked and none correct" do
          expect { count }.to change { counts }.from([10, 4]).to([11, 4])
        end
      end
    end

    context "with a statistics row holding no counts" do
      before { create(:question_statistic, question: question, number_asked: nil, number_correct: nil) }

      it "counts up from zero" do
        expect { count }.to change { counts }.from([nil, nil]).to([1, 1])
      end
    end
  end

  describe "the pupil's weekly count" do
    let(:this_week) { Date.current.beginning_of_week }

    context "with nothing counted this week" do
      it "starts the week at this answer" do
        count
        expect(UserStatistic.find_by!(user: student, week_beginning: this_week).questions_answered).to eq 1
      end
    end

    context "with answers counted this week" do
      let!(:weekly) { create(:user_statistic, user: student, week_beginning: this_week, questions_answered: 3) }

      it "adds one" do
        expect { count }.to change { weekly.reload.questions_answered }.from(3).to(4)
      end
    end

    context "with an answer given in an earlier week" do
      let(:answered_at) { 2.weeks.ago }
      let!(:weekly) { create(:user_statistic, user: student, week_beginning: this_week, questions_answered: 3) }

      it "counts it in the week it was given" do
        count
        expect(UserStatistic.find_by!(user: student, week_beginning: answered_at.to_date.beginning_of_week)
          .questions_answered).to eq 1
      end

      it "leaves this week's count alone" do
        expect { count }.not_to change { weekly.reload.questions_answered }
      end
    end
  end
end
