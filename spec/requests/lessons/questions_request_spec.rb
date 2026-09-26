# frozen_string_literal: true

require "rails_helper"

RSpec.describe "lesson questions controller", :default_creates do
  include ActionView::RecordIdentifier

  let(:lesson) { create(:lesson, topic: topic) }

  describe "GET /lessons/:lesson_id/questions" do
    describe "as a teacher" do
      let!(:teacher_enrollment) { create(:enrollment, user: teacher, classroom: classroom) }

      before { sign_in teacher }

      context "with a multiple-choice question" do
        let!(:question) do
          build(:question, lesson: lesson, topic: topic, question_text: "What do plants make in daylight?").tap do |q|
            q.answers.first.text = "Glucose"
            q.answers << build(:answer, question: q, text: "Oxygen", correct: false)
            q.save!
          end
        end
        let!(:retired_question) do
          create(:question, lesson: lesson, topic: topic, question_text: "Which gas do leaves take in?", active: false)
        end

        before { get lesson_questions_path(lesson) }

        it "lists the lesson's active questions" do
          expect(Capybara.string(response.body)).to have_text("What do plants make in daylight?")
            .and have_no_text("Which gas do leaves take in?")
            .and have_no_css("#no-questions")
        end

        it "offers no way to add or edit questions" do
          expect(Capybara.string(response.body)).to have_no_link("Add Question")
            .and have_no_link(href: edit_question_path(question))
        end

        it "marks the correct answer" do
          glucose = question.answers.find_by!(text: "Glucose")
          oxygen = question.answers.find_by!(text: "Oxygen")
          expect(Capybara.string(response.body))
            .to have_css("##{dom_id(glucose)} .badge", exact_text: "Correct")
            .and have_no_css("##{dom_id(oxygen)} .badge")
        end
      end

      context "with no questions" do
        before { get lesson_questions_path(lesson) }

        it "says the lesson has none" do
          expect(Capybara.string(response.body)).to have_css("#no-questions", text: "This lesson has no questions yet.")
        end

        it "links back to the lesson's topic on the Lessons page" do
          expect(Capybara.string(response.body))
            .to have_css("nav[aria-label='Breadcrumb'] a[href='#{lessons_path(open: topic.id)}']", exact_text: topic.name)
        end
      end

      context "with a question written before another" do
        let!(:later_question) { create(:question, lesson: lesson, topic: topic) }
        let!(:earlier_question) { create(:question, lesson: lesson, topic: topic, created_at: 1.day.ago) }

        before { get lesson_questions_path(lesson) }

        it "numbers the questions in the order they were written" do
          expect(Capybara.string(response.body))
            .to have_css("#lesson-questions > li:nth-of-type(1)##{dom_id(earlier_question)} h2", exact_text: "Question 1")
            .and have_css("#lesson-questions > li:nth-of-type(2)##{dom_id(later_question)} h2", exact_text: "Question 2")
        end
      end

      context "with a short-answer question" do
        let!(:short_answer) { create(:short_answer_question, lesson: lesson, topic: topic) }

        before { get lesson_questions_path(lesson) }

        it "lists its answers as accepted, marking none correct" do
          expect(Capybara.string(response.body))
            .to have_css("##{dom_id(short_answer)} .question-type", exact_text: "Short answer")
            .and have_css("##{dom_id(short_answer)}", text: "Accepted answers")
            .and have_no_css("##{dom_id(short_answer)} .answer .badge")
        end
      end

      context "with a true-or-false question saved False first" do
        let!(:true_or_false) do
          build(:boolean_question, lesson: lesson, topic: topic).tap do |q|
            q.answers.first.assign_attributes(text: "False", correct: false)
            q.answers.last.assign_attributes(text: "True", correct: true)
            q.save!
          end
        end

        before { get lesson_questions_path(lesson) }

        it "lists True before False, as a quiz does" do
          expect(Capybara.string(response.body))
            .to have_css("##{dom_id(true_or_false)} .answer:nth-child(1)", text: /\ATrue\b/)
            .and have_css("##{dom_id(true_or_false)} .answer:nth-child(2)", text: /\AFalse\b/)
        end
      end

      context "with a question that has no text" do
        let!(:untitled) { create(:question, :without_text, lesson: lesson, topic: topic) }

        before { get lesson_questions_path(lesson) }

        it "says so in place of the text" do
          expect(Capybara.string(response.body))
            .to have_css("##{dom_id(untitled)} .question-text", exact_text: "(no question text)")
        end
      end
    end

    describe "as a question author" do
      let(:author) { create(:question_author, subject: quiz_subject) }
      let!(:question) { create(:question, lesson: lesson, topic: topic) }

      before do
        sign_in author
        get lesson_questions_path(lesson)
      end

      it "marks Lessons, not Questions, as the current section" do
        expect(Capybara.string(response.body))
          .to have_css("#navbar-main .nav-link.active[aria-current='true'][href='#{lessons_path}']", exact_text: "Lessons")
          .and have_no_css("#navbar-main .nav-link.active[href='#{questions_path}']")
      end

      it "links each question to its editor" do
        expect(Capybara.string(response.body))
          .to have_css("a[href='#{edit_question_path(question)}'][aria-label='Edit question 1']", exact_text: "Edit")
      end

      it "adds new questions to this lesson" do
        expect(Capybara.string(response.body))
          .to have_link("Add Question", href: new_topic_question_path(topic, question: {lesson_id: lesson.id}))
      end
    end
  end
end
