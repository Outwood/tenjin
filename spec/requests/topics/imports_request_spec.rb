# frozen_string_literal: true

require "rails_helper"

RSpec.describe "topic imports controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  before { sign_in author }

  describe "POST /topics/:topic_id/import" do
    context "without an attached file" do
      it "re-renders the import form with an alert" do
        post topic_import_path(topic)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Please attach a file")
      end
    end
  end
end
