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
        expect(Capybara.string(response.body)).to have_text(ClassroomsHelper::SYNC_REFRESH_MESSAGE)
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
          .and have_no_text(ClassroomsHelper::SYNC_REFRESH_MESSAGE)
      end
    end
  end

  describe "PATCH /classrooms/:id" do
    before { sign_in school_admin }

    let(:new_subject) { create(:subject) }

    it "assigns the chosen subject to the classroom" do
      expect { patch classroom_path(classroom), params: {subject: new_subject.id} }
        .to change { classroom.reload.subject }.from(quiz_subject).to(new_subject)
    end

    it "marks the school as needing a sync" do
      expect { patch classroom_path(classroom), params: {subject: new_subject.id} }
        .to change { school.reload.sync_status }.to("needed")
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
