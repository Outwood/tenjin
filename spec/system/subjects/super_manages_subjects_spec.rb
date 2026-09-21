# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Super manages subjects", :default_creates do
  before { sign_in super_admin }

  # turbo_confirm smoke; the activation endpoint is covered in
  # spec/requests/system/subjects_request_spec.rb
  describe "deactivating a subject", :js do
    before { visit(edit_system_subject_path(quiz_subject)) }

    it "moves the subject to the deactivated list" do
      page.accept_confirm { click_button("Deactivate Subject") }
      expect(page).to have_css("#deactivated-subjects tr td", text: quiz_subject.name)
    end
  end
end
