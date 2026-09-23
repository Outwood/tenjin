# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeaderboardChannel, :default_creates do
  let(:viewer) { student }
  let!(:viewer_enrollment) do
    create(:enrollment, user: viewer, classroom: create(:classroom, school: viewer.school, subject: quiz_subject))
  end

  before { stub_connection current_user: viewer }

  context "when the school belongs to a school group" do
    before do
      subscribe(subject_id: quiz_subject.id, school: "Another School", school_group: "Another Group")
    end

    it "streams the group's leaderboard, ignoring the school the client names" do
      expect(subscription.streams)
        .to contain_exactly("leaderboard:subject-#{quiz_subject.id}:school-group-#{school.school_group_id}")
    end
  end

  context "when the school has no school group" do
    let(:viewer) { create(:student, school: school_without_school_group) }

    before { subscribe(subject_id: quiz_subject.id) }

    it "streams the school's leaderboard" do
      expect(subscription.streams)
        .to contain_exactly("leaderboard:subject-#{quiz_subject.id}:school-#{school_without_school_group.id}")
    end
  end

  context "with a subject the student is not enrolled in" do
    before { subscribe(subject_id: create(:subject).id) }

    it "rejects the subscription" do
      expect(subscription).to be_rejected
    end
  end

  context "with an unknown subject" do
    before { subscribe(subject_id: 0) }

    it "rejects the subscription" do
      expect(subscription).to be_rejected
    end
  end
end
