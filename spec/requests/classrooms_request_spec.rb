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

    context "with no pupils enrolled" do
      it "lists each homework as none complete out of none" do
        get classroom_path(classroom)
        expect(Capybara.string(response.body))
          .to have_css("#homework-table tbody tr", count: 3, text: "0 / 0 - 0%")
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
          .to have_css("#homework-table tr[data-id='#{homeworks.first.id}'] td", exact_text: "3 / 5 - 60%")
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

    describe "a pupil's homework ticks" do
      # Enrolled after the homeworks above, so the pupil has progress only on those set below
      let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }
      let(:pupil_row) { "#students-table tr[data-id='#{student.id}']" }

      context "with more homeworks than the row shows" do
        let!(:pupil_homeworks) do
          (1..6).map { |days| create(:homework, classroom: classroom, due_date: days.days.from_now) }
        end

        before do
          pupil_homeworks[4].homework_progresses.find_by!(user: student).update!(completed: true)
          get classroom_path(classroom)
        end

        it "shows five" do
          expect(Capybara.string(response.body)).to have_css("#{pupil_row} i", count: 5)
        end

        it "ticks a completed homework in its place, latest due first" do
          expect(Capybara.string(response.body))
            .to have_css("#{pupil_row} i.fa-check", count: 1)
            .and have_css("#{pupil_row} i:nth-child(2).fa-check")
        end
      end

      context "with the pupil's homework from another classroom" do
        let(:other_classroom) { create(:classroom, school: school) }
        let!(:other_enrollment) { create(:enrollment, classroom: other_classroom, user: student) }
        let!(:other_homework) { create(:homework, classroom: other_classroom) }

        before { get classroom_path(classroom) }

        it "leaves it off the pupil's row" do
          expect(Capybara.string(response.body)).to have_css(pupil_row).and have_no_css("#{pupil_row} i")
        end
      end
    end
  end
end
