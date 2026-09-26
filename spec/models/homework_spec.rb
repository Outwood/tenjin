# frozen_string_literal: true

require "rails_helper"

RSpec.describe Homework do
  let(:classroom) { create(:classroom_with_students, student_count: 2) }

  it "has a valid factory" do
    expect(build(:homework)).to be_valid
  end

  describe "validation" do
    subject { build(:homework, classroom: classroom, due_date: due_on) }

    let(:due_on) { 1.week.from_now }

    it { is_expected.to validate_presence_of(:due_date) }
    it { is_expected.to belong_to(:topic).required }
    it { is_expected.to validate_presence_of(:required) }

    it "is valid with a future due_date" do
      expect(subject).to be_valid
    end

    context "without a topic" do
      subject { build(:homework, topic: nil) }

      it "reports the missing topic once" do
        subject.validate
        expect(subject.errors.full_messages_for(:topic)).to contain_exactly("Topic can't be blank")
      end
    end

    context "with a topic from another subject" do
      subject { build(:homework, classroom: classroom, topic: create(:topic)) }

      it "names the topic as outside the class" do
        subject.validate
        expect(subject.errors.full_messages_for(:topic)).to contain_exactly("Topic isn't one of this class's topics")
      end
    end

    context "with a lesson" do
      subject { build(:homework, classroom: classroom, topic: topic, lesson: lesson) }

      let(:topic) { create(:topic, subject: classroom.subject) }

      context "when the lesson is in the topic" do
        let(:lesson) { create(:lesson, topic: topic) }

        it { is_expected.to be_valid }
      end

      context "when the lesson is in another topic" do
        let(:lesson) { create(:lesson, topic: create(:topic, subject: classroom.subject)) }

        it "names the lesson as outside the topic" do
          subject.validate
          expect(subject.errors.full_messages_for(:lesson_id)).to contain_exactly("Lesson isn't in the chosen topic")
        end
      end
    end

    context "when due earlier today on a summer day" do
      include ActiveSupport::Testing::TimeHelpers

      subject { build(:homework, classroom: classroom, due_date: "2030-07-01 09:00") }

      # 09:30 on UK clocks
      before { travel_to Time.utc(2030, 7, 1, 8, 30) }

      it "refuses the time as past" do
        subject.validate
        expect(subject.errors.full_messages_for(:due_date)).to contain_exactly("Due date can't be in the past")
      end
    end

    context "when due_date is in the past" do
      let(:due_on) { 1.day.ago }

      it { is_expected.not_to be_valid }
    end
  end

  describe "#save" do
    let(:homework) { build(:homework, classroom: classroom) }

    it "creates a progress record for each enrolled student" do
      expect { homework.save }.to change(HomeworkProgress, :count).by(2)
    end

    context "with a teacher enrolled in the class" do
      let(:teacher) { create(:teacher) }

      before { create(:enrollment, classroom: classroom, user: teacher) }

      it "does not create a progress record for teachers" do
        expect { homework.save }.to change(HomeworkProgress, :count).by(2)
      end
    end
  end

  describe "#assign_to" do
    let!(:homework) { create(:homework, classroom: classroom) }
    let(:enrolled) { classroom.users.first }
    let(:newcomer) { create(:student, school: classroom.school) }

    before { homework.homework_progresses.find_by!(user: enrolled).update!(progress: 60) }

    it "sets the homework for a pupil without it and keeps an existing pupil's row" do
      expect { homework.assign_to([enrolled.id, newcomer.id]) }.to change(HomeworkProgress, :count).by(1)
      expect(homework.homework_progresses.find_by!(user: enrolled).progress).to eq 60
      expect(homework.homework_progresses.find_by!(user: newcomer)).to have_attributes(progress: 0, completed_at: nil)
    end
  end

  describe "#state_for" do
    include ActiveSupport::Testing::TimeHelpers

    let(:homework) { build_stubbed(:homework, due_date: Time.zone.local(2026, 9, 24, 9)) }

    before { travel_to Time.zone.local(2026, 9, 23, 12) }

    it "is not set without a progress row" do
      expect(homework.state_for(nil)).to eq :not_set
    end

    it "is done for a completion by the due time" do
      progress = build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 24, 9))
      expect(homework.state_for(progress)).to eq :done
    end

    it "is done late for a completion after the due time" do
      progress = build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 24, 9, 1))
      expect(homework.state_for(progress)).to eq :done_late
    end

    it "is not yet due before the due time" do
      expect(homework.state_for(build_stubbed(:homework_progress, homework: homework))).to eq :not_due
    end

    context "when the due time has passed" do
      before { travel_to Time.zone.local(2026, 9, 24, 9, 1) }

      it "is overdue without a completion" do
        expect(homework.state_for(build_stubbed(:homework_progress, homework: homework))).to eq :overdue
      end
    end
  end

  describe "#destroy" do
    let!(:homework) { create(:homework, classroom: classroom) }

    it "deletes all progress records when destroyed" do
      expect { homework.destroy }.to change(HomeworkProgress, :count).by(-2)
    end
  end
end
