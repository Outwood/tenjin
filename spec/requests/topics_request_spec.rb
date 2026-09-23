# frozen_string_literal: true

require "rails_helper"

RSpec.describe "topics controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }
  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

  before { sign_in author }

  describe "PATCH /topics/:id" do
    it "renames the topic" do
      expect { patch topic_path(topic), params: {topic: {name: "Fractions"}} }
        .to change { topic.reload.name }.to("Fractions")
      expect(response).to have_http_status(:no_content)
    end

    context "with a lesson for the topic" do
      let(:lesson) { create(:lesson, topic: topic) }

      it "sets the default lesson" do
        expect { patch topic_path(topic), params: {topic: {default_lesson_id: lesson.id}} }
          .to change { topic.reload.default_lesson }.from(nil).to(lesson)
      end
    end

    context "when the record refuses the change" do
      before { patch topic_path(topic), params: {topic: {name: ""}}, headers: turbo_headers }

      it "leaves the name alone" do
        expect { topic.reload }.not_to change(topic, :name)
      end

      it "reports what the record refused" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(CGI.unescapeHTML(response.body)).to include("Topic not renamed: Name can't be blank")
      end
    end

    # The refusal reaches a caller that cannot process a stream, which only
    # this shared branch of ApplicationController#refuse answers
    context "when the refusal is not asked for as a stream" do
      before { patch topic_path(topic), params: {topic: {name: ""}}, headers: {"Accept" => "text/html"} }

      it "redirects back with the reason" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Topic not renamed: Name can't be blank")
      end
    end

    # Rails answers a bare */* with the first format refuse declares
    context "when the caller accepts any format" do
      before { patch topic_path(topic), params: {topic: {name: ""}}, headers: {"Accept" => "*/*"} }

      it "redirects back rather than answering with a stream" do
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /topics/:id" do
    it "destroys the topic and redirects to the questions index" do
      expect { delete topic_path(topic) }
        .to change { Topic.exists?(topic.id) }.from(true).to(false)
      expect(response).to redirect_to(questions_path)
    end

    context "when a callback halts the delete" do
      # No callback halts a topic destroy today, so the refusal is stubbed; the
      # branch is what keeps one added later from reading as a delete
      before do
        allow_any_instance_of(Topic).to receive(:destroy).and_return(false)
        delete topic_path(topic), headers: turbo_headers
      end

      it "keeps the topic" do
        expect(Topic.exists?(topic.id)).to be true
      end

      it "says so rather than reporting a delete it did not make" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Topic not deleted")
      end
    end
  end
end
