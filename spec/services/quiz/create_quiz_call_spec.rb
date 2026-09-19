# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quiz::CreateQuiz, :default_creates do
  context "when creating a lucky dip quiz" do
    let(:result) { described_class.call(user: student, topic: "Lucky Dip", subject: quiz_subject) }
    let(:topic_result) { described_class.call(user: student, topic: topic.id, subject: quiz_subject) }
    let(:topics) { create_list(:topic, 10, subject: quiz_subject) }

    before do
      topics.each do |t|
        create(:question, topic: t)
      end
      create(:question, topic: topic)
    end

    it "includes 10 questions" do
      expect(result.payload[:quiz].questions.count).to eq(10)
    end

    it "draws questions from multiple topics" do
      expect(result.payload[:quiz].questions.first.topic).not_to eq(result.payload[:quiz].questions.second.topic)
    end

    it "has no topic assigned" do
      expect(result.payload[:quiz].topic).to be_nil
    end

    it "assigns the topic for a non-lucky dip quiz" do
      expect(topic_result.payload[:quiz].topic).to eq(topic)
    end

    context "with a lesson" do
      let(:lesson) { create(:lesson, topic: topic) }
      let(:result) do
        described_class.call(user: student, topic: "Lucky Dip", subject: quiz_subject, lesson: lesson.id)
      end

      it "ignores the lesson" do
        expect(result.payload[:quiz].lesson).to be_nil
      end
    end

    it "records the time the quiz was started" do
      described_class.call(user: student, topic: "Lucky Dip", subject: quiz_subject)
      expect(student.reload.time_of_last_quiz).to be_within(1.second).of(Time.current)
    end

    context "with an inactive question" do
      let(:first_question) { topics.first.questions.first }

      before { first_question.update!(active: false) }

      it "excludes inactive questions" do
        expect(result.payload[:quiz].questions).not_to include(first_question)
      end
    end

    context "when the cooldown has not elapsed" do
      before { student.update!(time_of_last_quiz: Time.current) }

      it "returns an error" do
        expect(result).to be_failure
        expect(result.error).to match(code: :cooldown, seconds_left: be_positive)
      end
    end

    context "with no previous quiz time" do
      before { student.update!(time_of_last_quiz: nil) }

      it "creates a quiz" do
        expect(result).to be_success
      end
    end

    context "when no questions are available" do
      let(:result) { described_class.call(user: student, topic: "Lucky Dip", subject: create(:subject)) }

      it "returns an error" do
        expect(result).to be_failure
        expect(result.error).to eq("No questions are available for this topic")
      end

      it "does not save the quiz" do
        expect { result }.not_to change(Quiz, :count)
      end
    end
  end

  context "when creating a lesson based quiz" do
    let(:result) do
      described_class.call(user: student, topic: topic.id, subject: quiz_subject, lesson: lesson.id)
    end
    let(:lesson) { create(:lesson, topic: topic) }

    before do
      create_list(:question, 10, topic: topic, lesson: lesson)
      create_list(:question, 20, topic: topic)
    end

    it "includes only questions from the lesson" do
      expect(result.payload[:quiz].questions.where(lesson: lesson).count).to eq(10)
    end

    it "assigns the lesson to the quiz" do
      expect(result.payload[:quiz].lesson).to eq(lesson)
    end
  end

  context "when the topic belongs to another subject" do
    let(:other_topic) { create(:topic) }
    let(:result) { described_class.call(user: student, topic: other_topic.id, subject: quiz_subject) }

    # A question exists so only the topic guard can refuse
    before { create(:question, topic: other_topic) }

    it "returns a failure result" do
      expect(result).to be_failure
      expect(result.error).to eq "Topic not found"
    end

    it "does not save the quiz" do
      expect { result }.not_to change(Quiz, :count)
    end
  end

  context "when the lesson belongs to another topic" do
    let(:lesson) { create(:lesson) }
    let(:result) { described_class.call(user: student, topic: topic.id, subject: quiz_subject, lesson: lesson.id) }

    # Questions exist so only the lesson guard can refuse
    before { create_list(:question, 10, topic: lesson.topic, lesson: lesson) }

    it "returns a failure result" do
      expect(result).to be_failure
      expect(result.error).to eq "Lesson not found"
    end

    it "does not save the quiz" do
      expect { result }.not_to change(Quiz, :count)
    end
  end

  context "when the user is nil" do
    it "returns a failure result" do
      result = described_class.call(user: nil, topic: topic.id, subject: quiz_subject)
      expect(result).to be_failure
      expect(result.error).to eq "User not found"
    end
  end

  context "when the user is still in cooldown" do
    before { allow(student).to receive(:seconds_left_on_cooldown).and_return(45) }

    it "returns a structured rate-limited failure" do
      result = described_class.call(user: student, topic: topic.id, subject: quiz_subject)
      expect(result).to be_failure
      expect(result.error).to match(code: :cooldown, seconds_left: 45)
    end
  end

  context "when there are no available questions" do
    before { Question.where(topic: topic).update_all(active: false) }

    it "returns a failure result" do
      result = described_class.call(user: student, topic: topic.id, subject: quiz_subject)
      expect(result).to be_failure
      expect(result.error).to eq "No questions are available for this topic"
    end
  end

  context "when the topic has at least one question" do
    before { create(:question, topic: topic) }

    it "returns success with the quiz in the payload" do
      result = described_class.call(user: student, topic: topic.id, subject: quiz_subject)
      expect(result).to be_success
      expect(result.payload[:quiz]).to be_a(Quiz)
    end
  end
  context "when deciding whether the quiz counts for the leaderboard" do
    let(:result) { described_class.call(user: student, topic: topic.id, subject: quiz_subject) }

    before { create(:question, topic: topic) }

    it "counts the first attempt at a topic" do
      expect(result.payload[:quiz].counts_for_leaderboard).to be true
    end

    context "with two attempts at the topic today" do
      let!(:two_attempts_today) { create(:usage_statistic, user: student, topic: topic, quizzes_started: 2) }

      it "counts the third attempt" do
        expect(result.payload[:quiz].counts_for_leaderboard).to be true
      end
    end

    context "with three attempts at the topic today" do
      let!(:three_attempts_today) { create(:usage_statistic, user: student, topic: topic, quizzes_started: 3) }
      let(:lucky_dip_result) { described_class.call(user: student, topic: "Lucky Dip", subject: quiz_subject) }

      it "does not count the fourth attempt" do
        expect(result.payload[:quiz].counts_for_leaderboard).to be false
      end

      it "still counts a lucky dip" do
        expect(lucky_dip_result.payload[:quiz].counts_for_leaderboard).to be true
      end
    end
  end
end
