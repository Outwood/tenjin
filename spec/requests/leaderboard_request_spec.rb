# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leaderboard controller", :default_creates do
  let(:student_name) { "#{student.forename} #{student.surname[0]}" }

  before do
    create(:enrollment, classroom: classroom, user: student)
    sign_in student
  end

  describe "GET /leaderboards" do
    let!(:topic) { super() }
    let(:second_subject) { create(:subject) }
    let!(:second_enrollment) do
      create(:enrollment, classroom: create(:classroom, subject: second_subject, school: school), user: student)
    end

    before { get leaderboards_path }

    it "links each enrolled subject's overall and topic leaderboards" do
      expect(Capybara.string(response.body))
        .to have_link("All", href: subject_leaderboard_path(quiz_subject))
        .and have_link(topic.name, href: topic_leaderboard_path(topic))
        .and have_link("All", href: subject_leaderboard_path(second_subject))
    end

    it "does not list a subject the student is not enrolled in"
  end

  describe "GET /subjects/:subject_id/leaderboard" do
    describe "as a student" do
      before { get subject_leaderboard_path(quiz_subject) }

      it "does not offer the live leaderboard" do
        expect(Capybara.string(response.body)).to have_css(%([x-data*='"canSeeLiveToggle":false']))
      end
    end

    describe "as a teacher" do
      before do
        sign_in teacher
        get subject_leaderboard_path(quiz_subject)
      end

      it "offers the live leaderboard" do
        expect(Capybara.string(response.body)).to have_css(%([x-data*='"canSeeLiveToggle":true']))
      end
    end
  end

  describe "GET #show as JSON" do
    let!(:topic_score) { create(:topic_score, topic: topic, user: student, score: 10) }

    context "with the default filters" do
      before { get subject_leaderboard_path(quiz_subject, format: :json), xhr: true }

      it "returns the school's entries, the viewer and the subject name" do
        expect(response.parsed_body).to include(
          "name" => quiz_subject.name,
          "user" => {"id" => student.id, "role" => "student", "school" => school.name, "classrooms" => [classroom.name]},
          "leaderboard" => [a_hash_including("id" => student.id, "name" => student_name, "score" => 10,
            "school_name" => school.name, "classroom_names" => [classroom.name])]
        )
      end
    end

    context "with a topic" do
      let!(:other_topic_score) do
        create(:topic_score, topic: create(:topic, subject: quiz_subject), user: student, score: 20)
      end

      before { get topic_leaderboard_path(topic, format: :json), xhr: true }

      it "narrows the scores to that topic and names it" do
        expect(response.parsed_body)
          .to include("name" => topic.name, "leaderboard" => [a_hash_including("id" => student.id, "score" => 10)])
      end
    end

    context "with an all time score" do
      let!(:all_time_score) { create(:all_time_topic_score, user: student, topic: topic, score: 500) }

      before { get subject_leaderboard_path(quiz_subject, format: :json), params: {all_time: "true"}, xhr: true }

      it "lists all time scores in place of weekly scores" do
        expect(response.parsed_body["leaderboard"])
          .to contain_exactly(a_hash_including("id" => student.id, "score" => 500))
      end
    end

    context "with a school group" do
      let(:second_school) { create(:school, school_group: school.school_group, name: "Westbrook High") }
      let!(:second_school_score) { create(:topic_score, topic: topic, school: second_school, score: 20) }
      let!(:third_school) { create(:school, school_group: school.school_group, name: "Ashfield High") }

      context "when only the school is requested" do
        before { get subject_leaderboard_path(quiz_subject, format: :json), xhr: true }

        it "offers every school in the group as a filter" do
          expect(response.parsed_body["schools"])
            .to contain_exactly(school.name, "Ashfield High", "Westbrook High")
        end

        # default_creates names the student's school randomly, so only the pinned pair can be positioned
        it "orders the school filters by name" do
          expect(response.parsed_body["schools"] - [school.name]).to eq(["Ashfield High", "Westbrook High"])
        end

        it "lists only the school's entries" do
          expect(response.parsed_body["leaderboard"]).to contain_exactly(a_hash_including("id" => student.id))
        end
      end

      context "when the school group is requested" do
        before do
          get subject_leaderboard_path(quiz_subject, format: :json), params: {school_group: "true"}, xhr: true
        end

        it "lists entries from every school in the group" do
          expect(response.parsed_body["leaderboard"]).to contain_exactly(
            a_hash_including("id" => student.id), a_hash_including("id" => second_school_score.user_id)
          )
        end
      end
    end

    context "without a school group" do
      before do
        school.update!(school_group: nil)
        get subject_leaderboard_path(quiz_subject, format: :json), xhr: true
      end

      it "offers only the school as a filter" do
        expect(response.parsed_body["schools"]).to eq([school.name])
      end
    end

    context "with a subject that does not exist" do
      it "is not found" do
        expect { get subject_leaderboard_path(0, format: :json), xhr: true }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with classrooms in other subjects and schools" do
      let!(:second_classroom) { create(:classroom, subject: quiz_subject, school: school, name: "7 Beta") }
      let!(:third_classroom) { create(:classroom, subject: quiz_subject, school: school, name: "7 Alpha") }
      let!(:other_subject_classroom) { create(:classroom, school: school) }
      let!(:other_school_classroom) { create(:classroom, subject: quiz_subject) }

      before { get subject_leaderboard_path(quiz_subject, format: :json), xhr: true }

      it "offers only the school's classrooms for the subject as filters" do
        expect(response.parsed_body["classrooms"]).to contain_exactly(classroom.name, "7 Alpha", "7 Beta")
      end

      # default_creates names the student's classroom randomly, so only the pinned pair can be positioned
      it "orders the classroom filters by name" do
        expect(response.parsed_body["classrooms"] - [classroom.name]).to eq(["7 Alpha", "7 Beta"])
      end
    end

    context "with a classroom winner" do
      let!(:classroom_winner) { create(:classroom_winner, user: student, classroom: classroom, score: 100) }

      before { get subject_leaderboard_path(quiz_subject, format: :json), xhr: true }

      it "lists the winner by classroom with their initialled name" do
        expect(response.parsed_body["winners"]).to eq([[classroom.name, student_name, 100]])
      end
    end
  end
end
