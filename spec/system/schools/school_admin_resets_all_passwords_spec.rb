# frozen_string_literal: true

require "rails_helper"

RSpec.describe "School admin resets all passwords", :default_creates, :js do
  before do
    sign_in school_admin
    visit(school_path(school))
    click_button("Reset and print all passwords")
  end

  it "enables the confirm button only once the school name matches" do
    fill_in "confirmAllPasswordResetTextbox", with: "test"
    expect(page).to have_button("Confirm", disabled: true)
    fill_in "confirmAllPasswordResetTextbox", with: school.name
    expect(page).to have_button("Confirm")
  end

  # The job and redirect the request triggers are covered in spec/requests/schools_request_spec.rb
  it "acknowledges the request once confirmed" do
    fill_in "confirmAllPasswordResetTextbox", with: school.name
    click_button("Confirm")
    expect(page).to have_text("Request received")
  end
end
