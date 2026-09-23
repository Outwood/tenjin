# frozen_string_literal: true

require "rails_helper"

RSpec.describe School::AddSchool, :vcr do
  let(:school_token) { "faketoken0000000000000000000000000000000" }
  let(:school_id) { "A852030759" }
  let(:school_params) { ActionController::Parameters.new(token: school_token, client_id: school_id) }

  def sync_school
    described_class.call(school_params)
  end

  context "when no matching school exists" do
    before { sync_school }

    it "creates the school from the Wonde data" do
      expect(School.find_by(client_id: school_id).name).to eq "Outwood Grange Academy 1532082212"
    end
  end

  context "when a school with the same client_id exists" do
    before do
      create(:school, name: "Not outwood", client_id: "A852030759")
      sync_school
    end

    it "updates the school name in place without creating a duplicate" do
      expect(School.count).to eq(1)
      expect(School.find_by(client_id: school_id).name).to eq "Outwood Grange Academy 1532082212"
    end
  end
end

RSpec.describe School::AddSchool do
  # The id is typed by an admin, so whatever it holds must travel as one path segment
  context "when the id carries a character with meaning in a URL" do
    let(:school_params) { ActionController::Parameters.new(token: "a-token", client_id: "A852030759#x") }

    before do
      stub_request(:get, "https://api.wonde.com/v1.0/schools/A852030759%23x")
        .to_return(body: {"data" => {"id" => "A852030759#x", "name" => "Mistyped School"}}.to_json)
      described_class.call(school_params)
    end

    it "requests the school by the id as typed" do
      expect(a_request(:get, "https://api.wonde.com/v1.0/schools/A852030759%23x")).to have_been_made
    end
  end

  # Each failure comes back as an unsaved school, so the form re-renders with the reason
  describe "a school Wonde cannot supply" do
    let(:client_id) { "A000000000" }
    let(:token) { "a-token" }
    let(:school_url) { "https://api.wonde.com/v1.0/schools/#{client_id}" }
    let(:school) { described_class.call(ActionController::Parameters.new(token: token, client_id: client_id)) }

    context "with a blank id" do
      let(:client_id) { " " }

      it "asks Wonde nothing and reports the id missing" do
        expect(school).to be_new_record
          .and have_attributes(errors: have_attributes(details: {client_id: [{error: :blank}]}))
        expect(a_request(:get, /api\.wonde\.com/)).not_to have_been_made
      end
    end

    context "with a blank token" do
      let(:token) { "" }

      it "asks Wonde nothing and reports the token missing" do
        expect(school).to be_new_record
          .and have_attributes(errors: have_attributes(details: {token: [{error: :blank}]}))
        expect(a_request(:get, /api\.wonde\.com/)).not_to have_been_made
      end
    end

    context "when Wonde does not recognise the id" do
      before { stub_request(:get, school_url).to_return(status: 404, body: {error: "not_found"}.to_json) }

      it "reports the id, keeping what was typed" do
        expect(school).to be_new_record
          .and have_attributes(client_id: client_id, token: token,
            errors: have_attributes(details: {client_id: [{error: :not_on_wonde}]}))
      end
    end

    context "when the token has not been granted the school" do
      before { stub_request(:get, school_url).to_return(status: 403, body: {error: "access_denied"}.to_json) }

      it "reports the id" do
        expect(school).to be_new_record
          .and have_attributes(errors: have_attributes(details: {client_id: [{error: :not_on_wonde}]}))
      end
    end

    context "when Wonde refuses the token" do
      before { stub_request(:get, school_url).to_return(status: 401, body: {error: "invalid_token"}.to_json) }

      it "reports the token" do
        expect(school).to be_new_record
          .and have_attributes(errors: have_attributes(details: {token: [{error: :refused_by_wonde}]}))
      end
    end

    context "when Wonde does not answer" do
      before { stub_request(:get, school_url).to_timeout }

      it "reports the outage against the school as a whole" do
        expect(school).to be_new_record
          .and have_attributes(errors: have_attributes(details: {base: [{error: :wonde_unavailable}]}))
      end
    end
  end
end
