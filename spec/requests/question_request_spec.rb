# frozen_string_literal: true

require "rails_helper"

RSpec.describe "questions controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  describe "GET /questions" do
    context "as a student" do
      before { sign_in student }

      it "redirects to the dashboard" do
        get questions_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a question author" do
      before { sign_in author }

      it "returns a success response" do
        get questions_path
        expect(response).to have_http_status(:success)
      end

      context "with a topic of three questions and an empty topic" do
        let!(:questions) { create_list(:question, 3, topic: topic) }
        let!(:empty_topic) { create(:topic, subject: quiz_subject) }

        def topic_row(topic)
          Capybara.string(response.body)
            .find_link(href: topic_questions_path(topic))
            .ancestor("tr")
        end

        it "shows each topic's question count" do
          get questions_path
          expect(topic_row(topic)).to have_css("td:last-child", exact_text: "3")
          expect(topic_row(empty_topic)).to have_css("td:last-child", exact_text: "0")
        end

        # Loading every question row to count them scales with the question bank, not the page
        it "counts the questions in one query without loading them" do
          question_queries = []
          recorder = ->(*, payload) { question_queries << payload[:sql] if payload[:sql].include?('FROM "questions"') }
          ActiveSupport::Notifications.subscribed(recorder, "sql.active_record") do
            get questions_path
          end

          expect(question_queries).to contain_exactly(a_string_starting_with("SELECT COUNT"))
        end
      end
    end
  end

  describe "GET /questions/:id" do
    let(:question) { create(:question, topic: topic) }

    before { sign_in author }

    def ticked_answer(label) = "#table-answers tbody tr:has(input.text-answer[value='#{label}']) input.form-check-input[checked]"

    it "labels each select" do
      get question_path(question)
      expect(Capybara.string(response.body))
        .to have_select("Question Type").and have_select("Lesson:").and have_select("Topic:")
    end

    context "with a short answer question" do
      let(:question) { create(:short_answer_question, topic: topic) }

      before { get question_path(question) }

      it "hides the correct answer toggle" do
        expect(Capybara.string(response.body)).to have_no_css("#table-answers th", text: "Correct?")
      end
    end

    context "when previewing the question as boolean" do
      before { get question_path(question, question: {question_type: "boolean"}) }

      it "hides the remove answer links" do
        expect(Capybara.string(response.body)).to have_no_link("Remove")
      end

      it "labels the answers False and True" do
        expect(Capybara.string(response.body)).to have_field(with: "False").and have_field(with: "True")
      end
    end

    context "when previewing a three-answer question as boolean" do
      before do
        create_list(:answer, 2, question: question, correct: false)
        get question_path(question, question: {question_type: "boolean"})
      end

      it "deletes no answers" do
        expect(question.answers.count).to eq(3)
      end

      it "shows two answer rows" do
        expect(Capybara.string(response.body)).to have_css("#table-answers tbody tr", count: 2)
      end
    end

    context "with a boolean question whose labels need tidying" do
      let(:question) { create(:boolean_question, topic: topic) }

      before do
        question.answers.find_by!(correct: true).update_columns(text: "TRUE")
        question.answers.find_by!(correct: false).update_columns(text: "FALSE ")
        get question_path(question)
      end

      it "ticks the answer labelled True" do
        expect(Capybara.string(response.body))
          .to have_css(ticked_answer("True")).and have_no_css(ticked_answer("False"))
      end
    end

    context "when previewing as boolean a question with one True answer" do
      before do
        question.answers.first.update_columns(text: "True")
        create(:answer, question: question, correct: false, text: "Paris")
        get question_path(question, question: {question_type: "boolean"})
      end

      it "keeps the tick on True and labels the other answer False" do
        expect(Capybara.string(response.body))
          .to have_css(ticked_answer("True")).and have_no_css(ticked_answer("False")).and have_field(with: "False")
      end
    end

    context "when previewing as boolean a question with two True answers" do
      before do
        question.answers.first.update_columns(text: "True")
        create(:answer, question: question, correct: false, text: "true")
        get question_path(question, question: {question_type: "boolean"})
      end

      it "labels the answers False and True" do
        expect(Capybara.string(response.body)).to have_field(with: "False").and have_field(with: "True")
      end
    end

    context "with a question from another subject" do
      let(:question) { create(:question) }

      before { get question_path(question, question: {topic_id: topic.id}) }

      it "redirects with an alert" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "when previewing a move to another subject's topic" do
      before { get question_path(question, question: {topic_id: create(:topic).id}) }

      it "redirects with an alert" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "with a multiple choice question of three answers" do
      let!(:extra_answers) { create_list(:answer, 2, question: question) }

      before { get question_path(question) }

      it "shows the correct answer toggle" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers th", text: "Correct?")
          .and have_css("#table-answers tbody input.form-check-input", count: 3)
      end

      it "shows a remove link for each answer" do
        expect(Capybara.string(response.body)).to have_link("Remove", count: 3)
      end
    end
  end

  describe "PATCH /questions/:id" do
    let(:question) { create(:question, topic: topic) }
    let(:correct_answer) { question.answers.find_by!(correct: true) }

    before { sign_in author }

    context "with a lesson for the topic" do
      let(:lesson) { create(:lesson, topic: topic) }

      it "assigns the lesson" do
        expect { patch question_path(question), params: {question: {lesson_id: lesson.id}} }
          .to change { question.reload.lesson }.from(nil).to(lesson)
        expect(response).to redirect_to(question)
        expect(flash[:notice]).to eq("Question successfully updated")
      end
    end

    it "adds an answer" do
      patch question_path(question), params: {question: {answers_attributes: {"0" => {text: "Photosynthesis"}}}}
      expect(question.answers.reload).to contain_exactly(
        have_attributes(correct: true),
        have_attributes(text: "Photosynthesis")
      )
    end

    it "updates an answer's text" do
      expect do
        patch question_path(question),
          params: {question: {answers_attributes: {"0" => {id: correct_answer.id, text: "Photosynthesis"}}}}
      end.to change { correct_answer.reload.text }.to("Photosynthesis")
    end

    context "with an incorrect answer" do
      let(:incorrect_answer) { create(:answer, question: question, correct: false) }

      it "removes an answer flagged for destruction" do
        expect do
          patch question_path(question),
            params: {question: {answers_attributes: {"0" => {id: incorrect_answer.id, _destroy: "true"}}}}
        end.to change { Answer.exists?(incorrect_answer.id) }.from(true).to(false)
      end
    end

    context "when the only correct answer is removed" do
      it "keeps the answer and re-renders the editor with an error" do
        expect do
          patch question_path(question),
            params: {question: {answers_attributes: {"0" => {id: correct_answer.id, _destroy: "true"}}}}
        end.not_to change { Answer.exists?(correct_answer.id) }
        expect(response.body).to include("Question must have at least one correct answer")
      end
    end

    context "when no answer is marked correct" do
      before do
        patch question_path(question),
          params: {question: {answers_attributes: {"0" => {id: correct_answer.id, correct: "0"}}}}
      end

      it "re-renders the editor with an error" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Question must have at least one correct answer")
      end
    end

    context "with a short answer question" do
      let(:question) { create(:short_answer_question, topic: topic) }

      before do
        patch question_path(question), params: {question: {answers_attributes: {"0" => {text: "Photosynthesis"}}}}
      end

      it "marks every answer correct" do
        expect(question.answers.reload).to all(be_correct)
        expect(flash[:notice]).to eq("Question successfully updated")
      end
    end

    context "with a question from another subject" do
      let(:question) { create(:question) }

      it "leaves the question in its topic and redirects with an alert" do
        expect { patch question_path(question), params: {question: {topic_id: topic.id}} }
          .not_to change { question.reload.topic }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "when moving the question to another subject's topic" do
      let(:other_topic) { create(:topic) }

      it "leaves the question in its topic and redirects with an alert" do
        expect { patch question_path(question), params: {question: {topic_id: other_topic.id}} }
          .not_to change { question.reload.topic }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "with a boolean question whose labels need tidying" do
      let(:question) { create(:boolean_question, topic: topic) }
      let(:true_answer) { question.answers.find_by!(correct: true) }
      let(:false_answer) { question.answers.find_by!(correct: false) }

      before do
        true_answer.update_columns(text: "TRUE")
        false_answer.update_columns(text: "FALSE ")
        patch question_path(question), params: {question: {answers_attributes: {
          "0" => {id: true_answer.id, text: "TRUE", correct: "1"},
          "1" => {id: false_answer.id, text: "FALSE ", correct: "0"}
        }}}
      end

      it "keeps the correct answer on True" do
        expect(question.answers.reload).to contain_exactly(
          have_attributes(text: "True", correct: true),
          have_attributes(text: "False", correct: false)
        )
      end
    end

    context "when switching a three-answer question to boolean" do
      before do
        create_list(:answer, 2, question: question, correct: false)
        patch question_path(question), params: {question: {question_type: "boolean"}}
      end

      it "saves it with two answers" do
        expect(question.reload).to be_boolean
        expect(question.answers.count).to eq(2)
      end
    end

    context "with a boolean question that has three answers" do
      let(:question) { create(:boolean_question, topic: topic) }

      before do
        create(:answer, question: question, correct: false, text: "Maybe")
        patch question_path(question), params: {question: {question_text: "Is the sky blue?"}}
      end

      it "saves it with only the first two answers" do
        expect(question.answers.reload.map(&:text)).to contain_exactly("True", "False")
      end
    end

    context "with a boolean question whose True and False answers are not its first two" do
      before do
        question.answers.first.update_columns(text: "Maybe", correct: false)
        create(:answer, question: question, correct: false, text: "false")
        create(:answer, question: question, correct: true, text: "true")
        question.update_columns(question_type: "boolean")
        patch question_path(question), params: {question: {question_text: "Is the sky blue?"}}
      end

      it "keeps the answers that read True and False" do
        expect(question.answers.reload).to contain_exactly(
          have_attributes(text: "True", correct: true),
          have_attributes(text: "False", correct: false)
        )
      end
    end
  end

  describe "DELETE /questions/:id" do
    let(:question) { create(:question, topic: topic) }

    before { sign_in author }

    it "deactivates the question and redirects to its topic" do
      expect { delete question_path(question) }
        .to change { question.reload.active }.from(true).to(false)
      expect(response).to redirect_to(topic_questions_path(topic))
    end
  end

  describe "PATCH /questions/:id/reset_flags" do
    let(:question) { create(:question, topic: topic) }
    let!(:flag) { create(:flagged_question, question: question, user: student) }

    before { sign_in author }

    it "clears the question's flags" do
      expect { patch reset_flags_question_path(question) }
        .to change { question.reload.flagged_questions_count }.from(1).to(0)
      expect(response).to redirect_to(question)
    end

    context "when not authorized for the question's subject" do
      let(:author) { create(:question_author, subject: create(:subject)) }

      it "keeps the flags and redirects with an alert" do
        expect { patch reset_flags_question_path(question) }.not_to change(FlaggedQuestion, :count)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized to perform this action.")
      end
    end
  end
end
