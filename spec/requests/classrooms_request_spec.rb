# frozen_string_literal: true

require "rails_helper"

RSpec.describe "classrooms controller", :default_creates do
  describe "GET /classrooms" do
    include ActiveSupport::Testing::TimeHelpers

    before do
      sign_in school_admin
      school.update!(sync_status: :syncing)
    end

    context "while a sync is running" do
      before { get classrooms_path }

      it "asks for a refresh rather than offering a retry" do
        expect(Capybara.string(response.body)).to have_text(SchoolsHelper::SYNC_REFRESH_MESSAGE)
          .and have_no_button("Last Sync Timed Out. Press here to try again.")
      end
    end

    context "when the sync has run past its timeout" do
      before do
        travel School::SYNC_TIMEOUT + 1.minute
        get classrooms_path
      end

      it "offers a retry" do
        expect(Capybara.string(response.body)).to have_button("Last Sync Timed Out. Press here to try again.")
          .and have_no_text(SchoolsHelper::SYNC_REFRESH_MESSAGE)
      end
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
    # Homework only reaches the table once a pupil has progress on it
    let!(:enrollment) { create(:enrollment, classroom: classroom, user: student) }
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
  end
end
