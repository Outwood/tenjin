# frozen_string_literal: true

require "rails_helper"

RSpec.describe "homeworks controller", :default_creates do
  before { sign_in teacher }

  describe "GET /homeworks/new" do
    context "when no classroom is specified" do
      it "redirects to the dashboard" do
        get new_homework_path
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "with a classroom" do
      let!(:full_lesson) { create(:lesson, topic: topic, questions_count: 10) }
      let!(:short_lesson) { create(:lesson, topic: topic, questions_count: 9) }
      let(:page) { Capybara.string(response.body) }

      before { get new_homework_path(classroom: {classroom_id: classroom.id}) }

      it "lists no lessons before a topic is chosen" do
        expect(page).to have_select("Lesson (Optional)", disabled: true)
          .and have_no_css("#homework_lesson_id option", text: full_lesson.title)
      end

      it "offers only lessons with at least ten questions" do
        lessons = JSON.parse(page.find("[data-homework-lessons-value]")["data-homework-lessons-value"])
        expect(lessons).to contain_exactly(a_hash_including("id" => full_lesson.id))
      end
    end
  end

  describe "POST /homeworks" do
    let(:homework_params) { {classroom_id: classroom.id, topic_id: topic.id, due_date: 1.week.from_now, required: 70} }

    context "with a topic homework" do
      before { post homeworks_path, params: {homework: homework_params} }

      it "sets the homework for the topic" do
        expect(Homework.sole).to have_attributes(classroom: classroom, topic: topic, lesson: nil, required: 70)
      end

      it "redirects to the homework with a notice naming the topic" do
        expect(response).to redirect_to(homework_path(Homework.sole))
        expect(flash[:notice]).to eq("#{topic.name} homework set")
      end
    end

    context "with a lesson homework" do
      let(:lesson) { create(:lesson, topic: topic) }

      before { post homeworks_path, params: {homework: homework_params.merge(lesson_id: lesson.id)} }

      it "sets the homework for the lesson" do
        expect(Homework.sole).to have_attributes(topic: topic, lesson: lesson)
      end

      it "names the lesson in the notice" do
        expect(flash[:notice]).to eq("#{lesson.title} homework set")
      end
    end

    context "with a due date in the past" do
      it "sets no homework and re-renders the form with the error" do
        expect { post homeworks_path, params: {homework: homework_params.merge(due_date: 1.day.ago)} }
          .not_to change(Homework, :count)
        expect(Capybara.string(response.body)).to have_css("form", text: "can't be in the past")
      end
    end
  end

  describe "GET /homeworks/:id" do
    let!(:enrollments) { create_list(:enrollment, 10, classroom: classroom) }
    let(:homework) { create(:homework, classroom: classroom) }

    it "renders one row per enrolled student" do
      get homework_path(homework)
      expect(Capybara.string(response.body)).to have_css("tr.student-row", count: 10)
    end

    context "when a student has completed the homework" do
      before do
        homework.homework_progresses.first.update!(completed: true)
        get homework_path(homework)
      end

      it "reports the class completion percentage" do
        expect(Capybara.string(response.body)).to have_css(".display-4", text: "1 / 10 - 10%")
      end
    end

    context "when a student has partial progress" do
      before do
        homework.homework_progresses.first.update!(progress: 50)
        get homework_path(homework)
      end

      it "shows the student's progress percentage" do
        expect(Capybara.string(response.body)).to have_css("tr.student-row td", text: "50%")
      end
    end

    context "with a lesson homework" do
      let(:lesson) { create(:lesson, topic: topic) }
      let(:homework) { create(:homework, classroom: classroom, topic: topic, lesson: lesson) }

      it "shows the lesson and topic the homework was set for" do
        get homework_path(homework)
        expect(response.body).to include(lesson.title).and include(topic.name)
      end
    end
  end

  describe "DELETE /homeworks/:id" do
    let!(:homework) { create(:homework, classroom: classroom) }

    it "destroys the homework and redirects to the classroom" do
      expect { delete homework_path(homework) }
        .to change { Homework.count }.by(-1)
      expect(response).to redirect_to(classroom_path(classroom))
    end
  end
end
