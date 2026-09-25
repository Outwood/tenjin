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

  describe "GET /questions/:id/edit" do
    let(:question) { create(:question, topic: topic) }

    before { sign_in author }

    def ticked_answer(label) = "#table-answers tbody tr:has(input.text-answer[value='#{label}']) input.form-check-input[checked]"

    it "offers a lesson-free question as no lesson" do
      get edit_question_path(question)
      expect(Capybara.string(response.body)).to have_css("#question_lesson_id option:first-child[value='']", exact_text: "No lesson")
    end

    it "cancels back to the topic's questions" do
      get edit_question_path(question)
      expect(Capybara.string(response.body)).to have_link("Cancel", href: topic_questions_path(topic))
    end

    context "with a question never asked" do
      before { get edit_question_path(question) }

      it "says so in place of a percentage correct" do
        expect(Capybara.string(response.body)).to have_css("#question-statistics dd", exact_text: "Not asked yet")
      end

      it "offers no flag reset" do
        expect(Capybara.string(response.body)).to have_no_button("Reset Question Flags")
      end
    end

    context "with a question asked four times, three answered correctly, and flagged" do
      before do
        create(:question_statistic, question: question, number_asked: 4, number_correct: 3)
        create(:flagged_question, question: question, user: student)
        get edit_question_path(question)
      end

      it "shows the percentage correct" do
        expect(Capybara.string(response.body)).to have_css("#question-statistics dd", exact_text: "75%")
      end

      it "offers a flag reset" do
        expect(Capybara.string(response.body)).to have_button("Reset Question Flags")
      end
    end

    it "labels each select" do
      get edit_question_path(question)
      expect(Capybara.string(response.body))
        .to have_select("Question Type").and have_select("Lesson").and have_select("Topic")
    end

    context "with a short answer question" do
      let(:question) { create(:short_answer_question, topic: topic) }

      before { get edit_question_path(question) }

      it "hides the correct answer toggle" do
        expect(Capybara.string(response.body)).to have_no_css("#table-answers th", text: "Correct?")
      end

      it "heads each answer column and no other" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers thead th", count: 2)
          .and have_css("#table-answers tbody tr:first-of-type td", count: 2)
      end
    end

    context "when previewing the question as boolean" do
      before { get edit_question_path(question, question: {question_type: "boolean"}) }

      it "hides the remove answer buttons" do
        expect(Capybara.string(response.body)).to have_no_button("Remove")
      end

      it "labels the answers False and True" do
        expect(Capybara.string(response.body)).to have_field(with: "False").and have_field(with: "True")
      end
    end

    context "when previewing a three-answer question as boolean" do
      before do
        create_list(:answer, 2, question: question, correct: false)
        get edit_question_path(question, question: {question_type: "boolean"})
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
        get edit_question_path(question)
      end

      it "ticks the answer labelled True" do
        expect(Capybara.string(response.body))
          .to have_css(ticked_answer("True")).and have_no_css(ticked_answer("False"))
      end
    end

    context "with a boolean question" do
      let(:question) { create(:boolean_question, topic: topic) }

      before { get edit_question_path(question) }

      it "offers its answers as one choice of correct answer" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers input[type=radio][name='question[correct_answer]']", count: 2)
          .and have_no_css("#table-answers input[type=checkbox]")
      end

      it "heads each answer column and no other" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers thead th", count: 2)
          .and have_css("#table-answers tbody tr:first-of-type td", count: 2)
      end
    end

    context "with a boolean question whose answers are both marked correct" do
      let(:question) { create(:boolean_question, topic: topic) }

      before do
        question.answers.update_all(correct: true)
        get edit_question_path(question)
      end

      it "leaves the choice of correct answer to the author" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers input[type=radio]", count: 2)
          .and have_no_css("#table-answers input[type=radio][checked]")
      end
    end

    context "when previewing as multiple choice a boolean question with False chosen" do
      let(:question) { create(:boolean_question, topic: topic) }

      before { get edit_question_path(question, question: {question_type: "multiple", correct_answer: "False"}) }

      it "ticks only the False answer" do
        expect(Capybara.string(response.body))
          .to have_css(ticked_answer("false")).and have_no_css(ticked_answer("true"))
      end
    end

    context "with a boolean question whose stored labels carry stray whitespace" do
      let(:question) { create(:boolean_question, topic: topic) }

      before do
        # Raw SQL, since any write through the model normalises; the True answer is the older
        Answer.connection.execute(
          "UPDATE answers SET text = CASE WHEN correct THEN ' TRUE ' ELSE ' FALSE' END WHERE question_id = #{question.id}"
        )
        get edit_question_path(question)
      end

      it "ticks the answer labelled True" do
        expect(Capybara.string(response.body))
          .to have_css(ticked_answer("True")).and have_no_css(ticked_answer("False"))
      end
    end

    context "when previewing as boolean a three-answer question with one answer removed" do
      let!(:removed_answer) { create(:answer, question: question, correct: false, text: "Paris") }
      let!(:other_answer) { create(:answer, question: question, correct: false, text: "Rome") }

      before do
        get edit_question_path(question, question: {question_type: "boolean",
                                                    answers_attributes: {"0" => {id: removed_answer.id, _destroy: "true"}}})
      end

      def answer_row(answer)
        Capybara.string(response.body)
          .find("#table-answers tbody input[name$='[id]'][value='#{answer.id}']", visible: :all)
          .find(:xpath, "preceding-sibling::tr[1]", visible: :all)
      end

      it "shows the two answers left" do
        expect(Capybara.string(response.body)).to have_css("#table-answers tbody tr", count: 2)
        expect(answer_row(other_answer)).to be_visible
      end

      it "keeps the removed answer hidden and marked for deletion" do
        expect(answer_row(removed_answer)).not_to be_visible
        expect(answer_row(removed_answer)).to have_css("input[name$='[_destroy]'][value='true']", visible: :all)
      end
    end

    context "when previewing as boolean a question with one True answer" do
      before do
        question.answers.first.update_columns(text: "True")
        create(:answer, question: question, correct: false, text: "Paris")
        get edit_question_path(question, question: {question_type: "boolean"})
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
        get edit_question_path(question, question: {question_type: "boolean"})
      end

      it "labels the answers False and True" do
        expect(Capybara.string(response.body)).to have_field(with: "False").and have_field(with: "True")
      end
    end

    context "with a question from another subject" do
      let(:question) { create(:question) }

      before { get edit_question_path(question, question: {topic_id: topic.id}) }

      it "redirects with an alert" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "when previewing a move to another subject's topic" do
      before { get edit_question_path(question, question: {topic_id: create(:topic).id}) }

      it "redirects with an alert" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "with a multiple choice question of three answers" do
      let!(:extra_answers) { create_list(:answer, 2, question: question) }

      before { get edit_question_path(question) }

      it "shows the correct answer toggle" do
        expect(Capybara.string(response.body))
          .to have_css("#table-answers th", text: "Correct?")
          .and have_css("#table-answers tbody input.form-check-input", count: 3)
      end

      it "shows a remove button for each answer" do
        expect(Capybara.string(response.body)).to have_button("Remove", count: 3)
      end

      it "lets an added answer leave the form without a save" do
        template = Capybara.string(response.body).find("[data-action='click->nested-fields#add']")["data-fields"]
        expect(Capybara.string(template)).to have_css("[data-action='click->nested-fields#removeRow']")
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
        expect(response).to redirect_to(edit_question_path(question))
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

      context "when the save fails" do
        before do
          removal = {"0" => {id: incorrect_answer.id, _destroy: "true"}}
          patch question_path(question), params: {question: {question_text: "", answers_attributes: removal}}
        end

        it "keeps the answer hidden and marked for deletion" do
          expect(Capybara.string(response.body))
            .to have_css("#table-answers tbody tr[hidden] input[name$='[_destroy]'][value='true']", visible: :all, count: 1)
        end
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
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Question must have at least one correct answer")
      end
    end

    context "when an answer is left blank" do
      before do
        patch question_path(question), params: {question: {answers_attributes: {"0" => {id: correct_answer.id, text: ""}}}}
      end

      it "re-renders the editor with the error summarised and the answer marked" do
        expect(Capybara.string(response.body))
          .to have_css(".alert-danger li", exact_text: "Answer can't be blank")
          .and have_no_css(".alert-danger li", text: "is invalid")
          .and have_css("input#answer-text-0.is-invalid + p.error", exact_text: "can't be blank")
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

    context "when choosing False as a boolean question's correct answer" do
      let(:question) { create(:boolean_question, topic: topic) }

      before { patch question_path(question), params: {question: {correct_answer: "False"}} }

      it "marks only the False answer correct" do
        expect(question.answers.reload).to contain_exactly(
          have_attributes(text: "True", correct: false),
          have_attributes(text: "False", correct: true)
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

    context "with a boolean question that has three answers and its False answer removed" do
      let(:question) { create(:boolean_question, topic: topic) }
      let!(:true_answer) { question.answers.find_by!(correct: true) }
      let!(:removed_answer) { question.answers.find_by!(correct: false) }
      let!(:other_answer) { create(:answer, question: question, correct: false, text: "Maybe") }

      before do
        patch question_path(question),
          params: {question: {answers_attributes: {"0" => {id: removed_answer.id, _destroy: "true"}}}}
      end

      it "deletes the removed answer and relabels the one left False" do
        expect(question.answers.reload).to contain_exactly(
          have_attributes(id: true_answer.id, text: "True", correct: true),
          have_attributes(id: other_answer.id, text: "False", correct: false)
        )
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
      expect(flash[:notice]).to eq("Question deleted")
    end
  end
end
