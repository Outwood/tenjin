# frozen_string_literal: true

require "rails_helper"

RSpec.describe "topic questions controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  before { sign_in author }

  describe "GET /topics/:topic_id/questions" do
    let(:question) { create(:question, topic: topic) }

    context "with a flagged question never asked" do
      let!(:flags) { create_list(:flagged_question, 5, question: question) }

      before { get topic_questions_path(topic) }

      it "shows each question's flag count" do
        expect(Capybara.string(response.body))
          .to have_css("#question-#{question.id} td.flags", exact_text: "5")
      end

      it "links each question to its editor" do
        expect(Capybara.string(response.body))
          .to have_css("#question-#{question.id} td.question-text a[href='#{edit_question_path(question)}']")
      end

      it "says so in place of a percentage correct" do
        expect(Capybara.string(response.body))
          .to have_css("#question-#{question.id} td.correct", exact_text: "Not asked yet")
      end
    end

    context "with a question asked four times, three answered correctly" do
      let!(:statistic) { create(:question_statistic, question: question, number_asked: 4, number_correct: 3) }

      before { get topic_questions_path(topic) }

      it "shows the percentage correct" do
        expect(Capybara.string(response.body))
          .to have_css("#question-#{question.id} td.correct", exact_text: "75%")
      end
    end
  end

  describe "GET /topics/:topic_id/questions.json" do
    let!(:question) { create(:question, topic: topic) }

    it "responds with the questions as a JSON attachment named after the topic" do
      get topic_questions_path(topic, format: :json)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to start_with("application/json")
      expect(response.headers["Content-Disposition"])
        .to start_with("attachment").and include("filename*=UTF-8''#{topic.name}.json")
      expect(JSON.parse(response.body).first).to include("question_text", "answers")
    end

    context "when the topic name carries header syntax" do
      let(:punctuated_topic) { create(:topic, subject: quiz_subject, name: 'Forces, "motion"; é') }

      it "keeps the whole name in the encoded filename" do
        get topic_questions_path(punctuated_topic, format: :json)

        disposition = response.headers["Content-Disposition"]
        expect(CGI.unescape(disposition[/filename\*=UTF-8''(\S+)\z/, 1].to_s))
          .to eq('Forces, "motion"; é.json')
      end
    end
  end

  describe "GET /topics/:topic_id/questions/new" do
    context "with no type chosen" do
      before { get new_topic_question_path(topic) }

      it "starts a short answer question" do
        expect(Capybara.string(response.body))
          .to have_select("Question Type", selected: "Short answer")
          .and have_no_css("#table-answers th", text: "Correct?")
      end
    end

    context "when previewing the question as boolean" do
      before { get new_topic_question_path(topic, question: {question_type: "boolean"}) }

      it "labels the answers False and True" do
        expect(Capybara.string(response.body)).to have_field(with: "False").and have_field(with: "True")
      end

      it "shows no errors before a save" do
        expect(Capybara.string(response.body)).to have_no_css(".alert-danger").and have_no_css(".is-invalid")
      end
    end
  end

  describe "POST /topics/:topic_id/questions" do
    let(:question_params) do
      {question_text: "What do plants make in daylight?", question_type: "short_answer",
       answers_attributes: {"0" => {text: "Glucose"}}}
    end

    it "creates the question in the topic and redirects to its questions" do
      expect { post topic_questions_path(topic), params: {question: question_params} }
        .to change { topic.questions.count }.by(1)
      expect(response).to redirect_to(topic_questions_path(topic))
      expect(flash[:notice]).to eq("Question successfully created")
    end

    context "with another topic in the params" do
      let(:other_topic) { create(:topic, subject: quiz_subject) }

      it "creates the question in the topic of the path" do
        post topic_questions_path(topic), params: {question: question_params.merge(topic_id: other_topic.id)}
        expect(Question.last.topic).to eq(topic)
      end
    end

    context "without question text" do
      before { question_params.delete(:question_text) }

      it "creates nothing and re-renders the form with the error" do
        expect { post topic_questions_path(topic), params: {question: question_params} }
          .not_to change(Question, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_css(".alert-danger li", exact_text: "Question text can't be blank")
          .and have_css("trix-editor.is-invalid + p.error", exact_text: "can't be blank")
      end
    end

    context "when not authorized for the topic's subject" do
      let(:author) { create(:question_author, subject: create(:subject)) }

      it "creates nothing and redirects with an alert" do
        expect { post topic_questions_path(topic), params: {question: question_params} }
          .not_to change(Question, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end
end
