# frozen_string_literal: true

require "rails_helper"

RSpec.describe Leaderboard::BroadcastLeaderboardPoint, :default_creates do
  context "when the school has a school group" do
    let!(:topic_score) { create(:topic_score, user: student, topic: topic, score: 10) }
    let!(:sibling_topic_score) do
      create(:topic_score, user: student, topic: create(:topic, subject: quiz_subject), score: 20)
    end

    it "broadcasts the scores to the group's leaderboard" do
      expect { described_class.call(topic, student) }
        .to have_broadcasted_to("leaderboard:subject-#{quiz_subject.id}:school-group-#{school.school_group_id}")
        .with(a_hash_including(id: student.id, topic_score: 10, subject_score: 30))
    end
  end

  context "when the school has no school group" do
    let(:local_student) { create(:student, school: school_without_school_group) }
    let!(:topic_score) { create(:topic_score, user: local_student, topic: topic, score: 5) }

    it "broadcasts to the school's leaderboard" do
      expect { described_class.call(topic, local_student) }
        .to have_broadcasted_to("leaderboard:subject-#{quiz_subject.id}:school-#{school_without_school_group.id}")
    end
  end
end
