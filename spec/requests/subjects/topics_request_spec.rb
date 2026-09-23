# frozen_string_literal: true

require "rails_helper"

RSpec.describe "subject topics controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  before { sign_in author }

  describe "POST /subjects/:subject_id/topics" do
    subject(:create_topic) { post subject_topics_path(quiz_subject), params: {topic: {name: "Fractions"}} }

    it "creates the named topic and redirects to its questions" do
      expect { create_topic }.to change { quiz_subject.topics.where(name: "Fractions", active: true).count }.by(1)
      expect(response).to redirect_to(topic_questions_path(Topic.last))
      expect(flash[:notice]).to eq("Topic created")
    end

    context "without a name" do
      subject(:create_topic) { post subject_topics_path(quiz_subject), params: {topic: {name: ""}} }

      it "creates nothing and re-renders the form with the error" do
        expect { create_topic }.not_to change(Topic, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_text("can't be blank")
      end
    end

    context "when not authorized for the subject" do
      let(:author) { create(:question_author, subject: create(:subject)) }

      it "creates nothing and redirects with an alert" do
        expect { create_topic }.not_to change(Topic, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end
end
