# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubjectPolicy, :default_creates do
  subject(:policy) { described_class.new(actor, quiz_subject) }

  describe "#leaderboard?" do
    describe "as a student enrolled in the subject" do
      let(:actor) { student }

      let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }

      it { is_expected.to be_leaderboard }
    end

    describe "as a student not enrolled in the subject" do
      let(:actor) { student }

      it { is_expected.not_to be_leaderboard }
    end

    describe "as a teacher not enrolled in the subject" do
      let(:actor) { teacher }

      it { is_expected.to be_leaderboard }
    end

    describe "as a school admin not enrolled in the subject" do
      let(:actor) { school_admin }

      it { is_expected.to be_leaderboard }
    end
  end

  describe "#flagged_questions?" do
    context "as a question author for the subject" do
      let(:actor) { teacher }

      before { actor.add_role(:question_author, quiz_subject) }

      it { is_expected.to be_flagged_questions }
    end

    context "as a user without the question_author role for the subject" do
      let(:actor) { teacher }

      it { is_expected.not_to be_flagged_questions }
    end
  end

  describe "Scope" do
    subject(:resolved) { described_class::Scope.new(teacher, Subject).resolve }

    let!(:another_subject) { create(:subject) }

    it "includes every subject" do
      expect(resolved).to include(quiz_subject, another_subject)
    end
  end
end
