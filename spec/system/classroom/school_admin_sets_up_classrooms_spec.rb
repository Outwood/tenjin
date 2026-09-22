# frozen_string_literal: true

require "rails_helper"

RSpec.describe "School admin sets up classrooms", :default_creates, :js do
  let!(:classroom) { create(:classroom, school: school) }
  let!(:quiz_subject) { create(:subject) }

  before do
    sign_in school_admin
    visit(classrooms_path)
  end

  context "before a subject is set" do
    it "reads as synced" do
      expect(page).to have_css("#syncStatus", exact_text: "Synced.")
    end
  end

  context "when a subject is set" do
    before { select quiz_subject.name, from: "subject" }

    it "reads as needing a sync before the write has answered" do
      expect(page).to have_css("#syncStatus", exact_text: ClassroomsHelper::SYNC_NEEDED_NOTICE)
    end
  end

  context "when the classroom refuses the change" do
    # Only the model enforces client_id uniqueness, so a roster that reused an
    # id leaves a row every later save refuses
    let!(:twin) { create(:classroom, :sharing_a_client_id, school: school, client_id: classroom.client_id) }

    before do
      visit(classrooms_path)
      select quiz_subject.name, from: "classroom-#{classroom.id}"
    end

    it "explains the refusal" do
      expect(page).to have_content("Subject not changed: Client has already been taken")
    end

    it "puts the status back rather than leaving the class looking enrolled" do
      expect(page).to have_css("#syncStatus", exact_text: "Synced.")
    end

    it "puts the select back to the subject the class still has" do
      expect(page).to have_select("classroom-#{classroom.id}", selected: classroom.subject.name)
    end
  end
end
