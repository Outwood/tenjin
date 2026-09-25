# frozen_string_literal: true

require "rails_helper"

RSpec.describe "classrooms controller", :default_creates do
  describe "GET /classrooms" do
    let(:school) { create(:school, last_sync: Date.new(2026, 9, 3)) }

    before do
      sign_in school_admin
      get classrooms_path
    end

    # The wording of every sync state is covered in spec/helpers/classrooms_helper_spec.rb
    it "points to the school page for the sync instead of offering it" do
      expect(Capybara.string(response.body))
        .to have_css("#syncStatus", exact_text: "Last synced 3 Sep 2026.")
        .and have_link("School overview", href: school_path(school))
        .and have_no_css("form[action='#{school_sync_path(school)}']")
    end
  end

  describe "PATCH /classrooms/:id" do
    before { sign_in school_admin }

    let(:new_subject) { create(:subject) }
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

    it "assigns the chosen subject to the classroom" do
      expect { patch classroom_path(classroom), params: {subject: new_subject.id} }
        .to change { classroom.reload.subject }.from(quiz_subject).to(new_subject)
    end

    it "marks the school as needing a sync" do
      expect { patch classroom_path(classroom), params: {subject: new_subject.id} }
        .to change { school.reload.sync_status }.to("needed")
    end

    context "when the classroom refuses the change" do
      let!(:twin) { create(:classroom, :sharing_a_client_id, school: school, client_id: classroom.client_id) }

      before { patch classroom_path(classroom), params: {subject: new_subject.id}, headers: turbo_headers }

      it "leaves the subject alone" do
        expect { classroom.reload }.not_to change(classroom, :subject)
      end

      it "reports what the record refused" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Subject not changed: Client has already been taken")
      end
    end

    context "when the school refuses the sync flag" do
      # schools.name is nullable, so a row its own validation refuses can exist
      before do
        school.update_column(:name, nil)
        patch classroom_path(classroom), params: {subject: new_subject.id}, headers: turbo_headers
      end

      it "leaves the sync status alone" do
        expect { school.reload }.not_to change(school, :sync_status)
      end

      it "says the school was not marked, rather than claiming it was" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(CGI.unescapeHTML(response.body))
          .to include("Subject changed, but the school is not marked for a sync: Name can't be blank")
      end
    end
  end

  describe "GET /classrooms/:id" do
    let!(:homeworks) do
      Array.new(3) { create(:homework, classroom: classroom, topic: create(:topic, subject: quiz_subject)) }
    end

    before { sign_in school_admin }

    it "names every homework's topic" do
      get classroom_path(classroom)
      expect(Capybara.string(response.body))
        .to have_css("#homework-table tbody tr", count: 3)
        .and have_link(homeworks.first.topic.name, href: homework_path(homeworks.first))
    end

    # Naming each topic from its own row would load one topic per homework
    it "loads the homework topics in one query" do
      topic_queries = []
      recorder = ->(*, payload) { topic_queries << payload[:sql] if payload[:sql].include?('FROM "topics"') }
      ActiveSupport::Notifications.subscribed(recorder, "sql.active_record") do
        get classroom_path(classroom)
      end

      expect(topic_queries.size).to eq(1)
    end

    describe "a homework's lesson" do
      let!(:lesson_homeworks) do
        Array.new(2) { |i| create(:homework, classroom: classroom, lesson: create(:lesson, topic: topic, title: "Lesson #{i}"), topic: topic) }
      end

      def lesson_cell(homework) = "#homework-table tr[data-id='#{homework.id}'] td:nth-child(2)"

      it "names the lesson a homework was set on, or says it covers the whole topic" do
        get classroom_path(classroom)
        expect(Capybara.string(response.body))
          .to have_css(lesson_cell(lesson_homeworks.first), exact_text: "Lesson 0")
          .and have_css(lesson_cell(homeworks.first), exact_text: "Whole topic")
      end

      # Naming each lesson from its own row would load one lesson per homework
      it "loads the lessons in one query" do
        lesson_queries = []
        recorder = ->(*, payload) { lesson_queries << payload[:sql] if payload[:sql].include?('FROM "lessons"') }
        ActiveSupport::Notifications.subscribed(recorder, "sql.active_record") do
          get classroom_path(classroom)
        end

        expect(lesson_queries.size).to eq(1)
      end
    end

    context "with no pupils enrolled" do
      it "says each homework has no pupils" do
        get classroom_path(classroom)
        expect(Capybara.string(response.body))
          .to have_css("#homework-table tbody td", count: 3, exact_text: "No pupils")
      end
    end

    context "with some of a homework completed" do
      before do
        create_list(:homework_progress, 2, homework: homeworks.first, completed: false)
        create_list(:homework_progress, 3, homework: homeworks.first, completed: true)
        get classroom_path(classroom)
      end

      it "reports the share completed" do
        expect(Capybara.string(response.body))
          .to have_css("#homework-table tr[data-id='#{homeworks.first.id}'] td", exact_text: "60% (3 of 5)")
      end
    end

    describe "the pupil list" do
      # Enrolled out of name order, so the listing cannot pass on creation order
      let!(:young) { create(:enrollment, classroom: classroom, user: create(:student, school: school, forename: "Ada", surname: "Young")).user }
      let!(:ben_adams) { create(:enrollment, classroom: classroom, user: create(:student, school: school, forename: "Ben", surname: "Adams")).user }
      let!(:amy_adams) { create(:enrollment, classroom: classroom, user: create(:student, school: school, forename: "Amy", surname: "Adams")).user }

      before { get classroom_path(classroom) }

      it "lists pupils by surname, then forename" do
        expect(Capybara.string(response.body))
          .to have_css("#students-table tbody tr:nth-child(1)[data-id='#{amy_adams.id}']")
          .and have_css("#students-table tbody tr:nth-child(2)[data-id='#{ben_adams.id}']")
          .and have_css("#students-table tbody tr:nth-child(3)[data-id='#{young.id}']")
      end
    end

    describe "a pupil's actions menu" do
      let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }

      before { get classroom_path(classroom) }

      it "is named for the pupil and resets their password" do
        row = Capybara.string(response.body).find("#students-table tr[data-id='#{student.id}']")
        expect(row).to have_button("Actions for #{student.forename} #{student.surname}", enable_aria_label: true)
          .and have_button("Reset password")
          .and have_css("button[data-password-reset-url-param='#{user_password_reset_path(student)}']")
      end
    end

    describe "a pupil's homework strip" do
      # Enrolled after the homeworks above, so the pupil has progress only on those set below
      let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }
      let(:pupil_row) { "#students-table tr[data-id='#{student.id}']" }

      def slot(homework) = "#{pupil_row} .homework-slot[data-homework='#{homework.id}']"

      context "with more homeworks than the strip holds" do
        # Due after every homework above, so these six hold the latest due dates
        let!(:pupil_homeworks) do
          (10..15).map { |days| create(:homework, classroom: classroom, due_date: days.days.from_now) }
        end

        before do
          pupil_homeworks[2].homework_progresses.find_by!(user: student).update!(completed: true)
          get classroom_path(classroom)
        end

        it "shows the five due latest, earliest due first" do
          expect(Capybara.string(response.body))
            .to have_css("#{pupil_row} .homework-slot", count: 5)
            .and have_css("#{pupil_row} .homework-slot:nth-child(1)[data-homework='#{pupil_homeworks[1].id}']")
            .and have_css("#{pupil_row} .homework-slot:nth-child(5)[data-homework='#{pupil_homeworks[5].id}']")
        end

        it "marks a completed homework in its own slot" do
          expect(Capybara.string(response.body))
            .to have_css("#{pupil_row} i.fa-check", count: 1)
            .and have_css("#{slot(pupil_homeworks[2])} i.fa-check")
        end
      end

      context "with homework set before the pupil joined" do
        before { get classroom_path(classroom) }

        it "gives it a slot marked as set before they joined" do
          expect(Capybara.string(response.body)).to have_css("#{slot(homeworks.first)} i.fa-minus")
        end
      end

      context "with the pupil's homework from another classroom" do
        let(:other_classroom) { create(:classroom, school: school) }
        let!(:other_enrollment) { create(:enrollment, classroom: other_classroom, user: student) }
        let!(:other_homework) { create(:homework, classroom: other_classroom) }

        before { get classroom_path(classroom) }

        it "leaves it off the pupil's strip" do
          expect(Capybara.string(response.body))
            .to have_css(slot(homeworks.first))
            .and have_no_css(slot(other_homework))
        end
      end
    end
  end
end
