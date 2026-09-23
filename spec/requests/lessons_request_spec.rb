# frozen_string_literal: true

require "rails_helper"

RSpec.describe "lessons controller", :default_creates do
  describe "GET /lessons" do
    let!(:lesson) { create(:lesson, topic: topic) }
    let!(:enrollment) { create(:enrollment, user: student, classroom: classroom) }

    describe "as a student" do
      let!(:no_content_lesson) do
        create(:lesson, topic: topic, category: "no_content", video_id: nil)
      end

      before { sign_in student }

      it "hides no_content lessons" do
        get lessons_path

        expect(response.body).to include(lesson.title)
        expect(response.body).not_to include(no_content_lesson.title)
      end
    end

    describe "as a lesson author whose subjects have no lessons" do
      let(:empty_subject) { create(:subject, name: "Woodwork") }

      before do
        teacher.add_role :lesson_author, empty_subject
        sign_in teacher
        get lessons_path
      end

      it "offers to add the first lesson" do
        expect(Capybara.string(response.body))
          .to have_no_css(".lesson-title", visible: :all)
          .and have_link("Add Lesson", href: new_subject_lesson_path(empty_subject))
      end
    end

    describe "as a lesson author" do
      before do
        teacher.add_role :lesson_author, quiz_subject
        sign_in teacher
      end

      # Lesson rows sit inside collapsed <details>, which Capybara treats as hidden

      context "with lessons in multiple subjects" do
        let(:other_subject) { create(:subject, name: "Woodwork") }
        let!(:other_lesson) do
          create(:lesson, title: "Joinery joints", topic: create(:topic, subject: other_subject))
        end

        before { get lessons_path }

        it "lists and offers to edit only lessons in authored subjects" do
          expect(Capybara.string(response.body))
            .to have_link("Edit", count: 1, visible: :all)
            .and have_css(".subject-title", text: quiz_subject.name)
            .and have_no_css(".subject-title", text: other_subject.name)
            .and have_css(".lesson-title", text: lesson.title, visible: :all)
            .and have_no_css(".lesson-title", text: other_lesson.title, visible: :all)
        end

        it "offers to add lessons only to authored subjects" do
          expect(Capybara.string(response.body))
            .to have_link("Add Lesson", count: 1)
            .and have_link("Add Lesson", href: new_subject_lesson_path(quiz_subject))
        end
      end

      context "with an authored subject that has no lessons" do
        let(:empty_subject) { create(:subject, name: "Woodwork") }

        before do
          teacher.add_role :lesson_author, empty_subject
          get lessons_path
        end

        it "offers to add a lesson to it" do
          expect(Capybara.string(response.body))
            .to have_css(".subject-title", text: empty_subject.name)
            .and have_link("Add Lesson", href: new_subject_lesson_path(empty_subject))
        end
      end

      context "with lessons in several topics" do
        let(:fractions) { create(:topic, subject: quiz_subject, name: "Fractions") }
        let(:retired) { create(:topic, subject: quiz_subject, name: "Photosynthesis", active: false) }
        let!(:fractions_lesson) { create(:lesson, title: "Adding fractions", topic: fractions) }
        let!(:retired_lesson) { create(:lesson, title: "Leaf structure", topic: retired) }
        let(:open_param) { nil }

        before { get lessons_path(open: open_param) }

        it "lists each lesson under its topic" do
          expect(Capybara.string(response.body))
            .to have_css("#topic_#{fractions.id} summary", text: "Fractions")
            .and have_css("#topic_#{fractions.id} .lesson-title", text: fractions_lesson.title, visible: :all)
            .and have_no_css("#topic_#{fractions.id} .lesson-title", text: lesson.title, visible: :all)
        end

        it "folds inactive topics into one group" do
          expect(Capybara.string(response.body))
            .to have_css("#inactive_topics_#{quiz_subject.id} #topic_#{retired.id}", visible: :all)
            .and have_no_css("#inactive_topics_#{quiz_subject.id} #topic_#{fractions.id}", visible: :all)
        end

        it "starts with every topic closed" do
          expect(Capybara.string(response.body)).to have_no_css("details[open]", visible: :all)
        end

        context "when returning to an active topic" do
          let(:open_param) { fractions.id }

          it "opens and scrolls to only that topic" do
            expect(Capybara.string(response.body))
              .to have_css("details[open]", count: 1, visible: :all)
              .and have_css("[data-controller='scroll-into-view']", count: 1, visible: :all)
              .and have_css("details#topic_#{fractions.id}[open][data-controller='scroll-into-view']")
          end
        end

        context "when returning to an inactive topic" do
          let(:open_param) { retired.id }

          it "opens the topic inside the inactive group" do
            expect(Capybara.string(response.body))
              .to have_css("details#inactive_topics_#{quiz_subject.id}[open] details#topic_#{retired.id}[open]")
          end
        end

        context "when the topic parameter is not an id" do
          let(:open_param) { [fractions.id] }

          it "opens no topic" do
            expect(Capybara.string(response.body)).to have_no_css("details[open]", visible: :all)
          end
        end
      end

      context "with questions on its lessons" do
        let!(:revision_lesson) do
          create(:lesson, title: "Pythagoras revision", topic: topic, category: "no_content", video_id: nil)
        end
        let!(:unused_lesson) do
          create(:lesson, title: "Circle theorems", topic: topic, category: "no_content", video_id: nil)
        end

        before do
          create_list(:question, 2, topic: topic, lesson: revision_lesson)
          create(:question, topic: topic, lesson: revision_lesson, active: false)
          create(:question, topic: topic, lesson: lesson)
          create(:question, topic: topic, lesson: lesson, active: false)
          get lessons_path
        end

        it "counts each lesson's active questions" do
          expect(Capybara.string(response.body)).to have_table(
            visible: :all,
            with_rows: [
              {"Lesson" => lesson.title, "Questions" => "1"},
              {"Lesson" => revision_lesson.title, "Questions" => "2"},
              {"Lesson" => unused_lesson.title, "Questions" => "0"}
            ]
          )
        end

        it "totals the topic's lessons and active questions" do
          expect(Capybara.string(response.body))
            .to have_css("#topic_#{topic.id} summary", text: "3 lessons · 3 questions")
        end

        it "offers to play only the lesson with a video" do
          expect(Capybara.string(response.body))
            .to have_css("#topic_#{topic.id} button[data-video-url]", count: 1, visible: :all)
            .and have_css("button[data-video-url='#{lesson.video_url}']", visible: :all)
        end
      end
    end
  end

  describe "POST /lessons" do
    let(:title) { "Vimeo video lesson" }
    let(:params) do
      {lesson: {title: title, video_link: "https://vimeo.com/371104836", topic_id: topic.id}}
    end

    before do
      teacher.add_role :lesson_author, quiz_subject
      sign_in teacher
    end

    it "creates the lesson and returns to its topic" do
      expect { post lessons_path, params: params }.to change(Lesson, :count).by(1)
      expect(Lesson.find_by!(title: title))
        .to have_attributes(topic: topic, category: "vimeo", video_id: "371104836")
      expect(response).to redirect_to(lessons_path(open: topic.id))
    end

    context "when the details are invalid" do
      let(:title) { "ab" }
      let!(:inactive_topic) { create(:topic, subject: quiz_subject, name: "Photosynthesis", active: false) }

      it "re-renders the new form with errors" do
        expect { post lessons_path, params: params }.not_to change(Lesson, :count)
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Create Lesson")
          .and have_css(".invalid-feedback", text: "too short")
      end

      it "offers the subject's active topics in the re-rendered form" do
        post lessons_path, params: params
        expect(Capybara.string(response.body))
          .to have_select("lesson[topic_id]", options: ["", topic.name])
      end
    end
  end

  describe "PATCH /lessons/:id" do
    let(:lesson) { create(:lesson, topic: topic, video_id: "VFZNvj-HfBU") }

    before do
      teacher.add_role :lesson_author, quiz_subject
      sign_in teacher
    end

    it "saves the new details and keeps the video from the pre-filled link" do
      # The edit form posts back the embed link, not the link the author typed
      patch lesson_path(lesson),
        params: {lesson: {title: "Fantastic new title", video_link: lesson.video_url}}
      expect(lesson.reload)
        .to have_attributes(title: "Fantastic new title", category: "youtube", video_id: "VFZNvj-HfBU")
      expect(response).to redirect_to(lessons_path(open: topic.id))
    end

    context "when the details are invalid" do
      let!(:inactive_topic) { create(:topic, subject: quiz_subject, name: "Photosynthesis", active: false) }

      it "re-renders the edit form with errors" do
        expect { patch lesson_path(lesson), params: {lesson: {title: "ab"}} }
          .not_to change { lesson.reload.title }
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Update Lesson")
          .and have_css(".invalid-feedback", text: "too short")
      end

      it "offers the subject's active topics in the re-rendered form" do
        patch lesson_path(lesson), params: {lesson: {title: "ab"}}
        expect(Capybara.string(response.body))
          .to have_select("lesson[topic_id]", options: ["", topic.name])
      end
    end
  end

  describe "DELETE /lessons/:id" do
    let!(:lesson) { create(:lesson, topic: topic) }

    before do
      teacher.add_role :lesson_author, quiz_subject
      sign_in teacher
    end

    it "destroys the lesson and returns to its topic" do
      expect { delete lesson_path(lesson) }.to change(Lesson, :count).by(-1)
      expect(response).to redirect_to(lessons_path(open: topic.id))
    end
  end
end
