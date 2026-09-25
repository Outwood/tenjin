# frozen_string_literal: true

require "rails_helper"

RSpec.describe "School admin sets up classrooms", :default_creates, :js do
  # Only the model enforces client_id uniqueness, so a roster that reused an
  # id leaves a row every later save refuses
  let!(:twin) { create(:classroom, :sharing_a_client_id, school: school, client_id: classroom.client_id) }
  let!(:other_classroom) { create(:classroom, school: school) }
  let!(:new_subject) { create(:subject) }

  before do
    sign_in school_admin
    visit(classrooms_path)
  end

  # Smoke for the auto-submit and sync-notice wiring on this page; their branches are covered in
  # spec/javascript/controllers/, and the write in spec/requests/classrooms_request_spec.rb
  it "puts a refused change back, then flags a sync for one that lands" do
    select new_subject.name, from: "classroom-#{classroom.id}"
    expect(page).to have_content("Subject not changed: Client has already been taken")
      .and have_css("#syncStatus", exact_text: "Synced.")
      .and have_select("classroom-#{classroom.id}", selected: quiz_subject.name)

    select new_subject.name, from: "classroom-#{other_classroom.id}"
    expect(page).to have_css("#syncStatus", exact_text: ClassroomsHelper::SYNC_NEEDED_NOTICE)
  end
end
