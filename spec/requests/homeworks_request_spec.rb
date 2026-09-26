# frozen_string_literal: true

require "rails_helper"

RSpec.describe "homeworks controller", :default_creates do
  before { sign_in teacher }

  describe "GET /classrooms/:classroom_id/homeworks/new" do
    context "with a classroom" do
      let!(:full_lesson) { create(:lesson, topic: topic, questions_count: 10) }
      let!(:short_lesson) { create(:lesson, topic: topic, questions_count: 9) }
      let(:page) { Capybara.string(response.body) }

      before { get new_classroom_homework_path(classroom) }

      it "lists no lessons before a topic is chosen" do
        expect(page).to have_select("Lesson (Optional)", disabled: true, options: [""])
      end

      it "offers only lessons with at least ten questions" do
        lessons = JSON.parse(page.find("[data-homework-lessons-value]")["data-homework-lessons-value"])
        expect(lessons).to contain_exactly(a_hash_including("id" => full_lesson.id))
      end
    end
  end

  describe "POST /classrooms/:classroom_id/homeworks" do
    let(:homework_params) { {topic_id: topic.id, due_date: 1.week.from_now, required: 70} }

    context "with a topic homework" do
      before { post classroom_homeworks_path(classroom), params: {homework: homework_params} }

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

      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(lesson_id: lesson.id)} }

      it "sets the homework for the lesson" do
        expect(Homework.sole).to have_attributes(topic: topic, lesson: lesson)
      end

      it "names the lesson in the notice" do
        expect(flash[:notice]).to eq("#{lesson.title} homework set")
      end
    end

    context "with another school's classroom" do
      let(:other_classroom) { create(:classroom, subject: quiz_subject) }

      it "sets no homework and redirects with an alert" do
        expect { post classroom_homeworks_path(other_classroom), params: {homework: homework_params} }
          .not_to change(Homework, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end

    context "with a due date in the past" do
      it "sets no homework and re-renders the form with the error" do
        expect { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(due_date: 1.day.ago)} }
          .not_to change(Homework, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_css("form", text: "can't be in the past")
      end
    end

    context "with a lesson homework and a due date in the past" do
      let(:lesson) { create(:lesson, topic: topic, title: "Equivalent fractions", questions_count: 10) }
      let!(:sibling_lesson) { create(:lesson, topic: topic, title: "Mixed numbers", questions_count: 10) }

      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(lesson_id: lesson.id, due_date: 1.day.ago)} }

      it "keeps the chosen lesson among the topic's lessons" do
        expect(Capybara.string(response.body))
          .to have_select("Lesson (Optional)", disabled: false, selected: "Equivalent fractions",
            options: ["", "Equivalent fractions", "Mixed numbers"])
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
        expect(Capybara.string(response.body)).to have_css("#homework-completion", exact_text: "10% (1 of 10)")
      end

      it "names each pupil's status beside its icon" do
        expect(Capybara.string(response.body))
          .to have_css("tr.student-row td:nth-child(2)", exact_text: "Complete", count: 1)
          .and have_css("tr.student-row td:nth-child(2)", exact_text: "Not complete", count: 9)
      end
    end

    context "with a pupil who has moved to another class" do
      let!(:mover_enrollment) { create(:enrollment, classroom: classroom, user: student) }

      # The move comes after the homework, as a sync would make it, so the mover keeps a completed row on it
      before do
        [enrollments.first.user, student].each { |pupil| homework.homework_progresses.find_by!(user: pupil).update!(completed: true) }
        mover_enrollment.destroy!
        create(:enrollment, classroom: create(:classroom, school: school), user: student)
        get homework_path(homework)
      end

      it "counts only the pupils still in the class" do
        expect(Capybara.string(response.body)).to have_css("#homework-completion", exact_text: "10% (1 of 10)")
      end

      it "leaves the mover out of the pupil list" do
        expect(Capybara.string(response.body))
          .to have_css("tr.student-row", count: 10)
          .and have_no_css("tr.student-row[data-user='#{student.id}']")
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

    context "with no pupils enrolled in the class" do
      let(:empty_classroom) { create(:classroom, school: school, subject: quiz_subject) }
      let(:homework) { create(:homework, classroom: empty_classroom) }

      it "says the homework has no pupils" do
        get homework_path(homework)
        expect(Capybara.string(response.body)).to have_css("#homework-completion", exact_text: "No pupils")
      end
    end

    context "with a lesson homework" do
      let(:lesson) { create(:lesson, topic: topic) }
      let(:homework) { create(:homework, classroom: classroom, topic: topic, lesson: lesson, required: 70) }

      it "heads the page with the lesson and names its topic beneath" do
        get homework_path(homework)
        expect(Capybara.string(response.body)).to have_css("h1", exact_text: lesson.title)
          .and have_css("h1 + p.lead", exact_text: "#{topic.name} - 70% required")
      end
    end

    context "with a whole-topic homework" do
      let(:homework) { create(:homework, classroom: classroom, topic: topic, required: 70) }

      it "heads the page with the topic, without repeating it beneath" do
        get homework_path(homework)
        expect(Capybara.string(response.body)).to have_css("h1", exact_text: topic.name)
          .and have_css("h1 + p.lead", exact_text: "Whole topic - 70% required")
      end
    end

    it "links back to the class in the breadcrumb" do
      get homework_path(homework)
      expect(Capybara.string(response.body))
        .to have_css("nav[aria-label='Breadcrumb'] a[href='#{classroom_path(classroom)}']", exact_text: classroom.name)
    end

    it "asks for confirmation before deleting the homework" do
      get homework_path(homework)
      expect(Capybara.string(response.body))
        .to have_css("form[action='#{homework_path(homework)}'][data-turbo-confirm*='progress']")
    end
  end

  describe "DELETE /homeworks/:id" do
    let!(:homework) { create(:homework, classroom: classroom) }

    it "destroys the homework and redirects to the classroom" do
      expect { delete homework_path(homework) }
        .to change { Homework.count }.by(-1)
      expect(response).to redirect_to(classroom_path(classroom))
      expect(response).to have_http_status(:see_other)
    end

    it "names the deleted homework in the notice" do
      delete homework_path(homework)
      expect(flash[:notice]).to eq("#{homework.topic.name} homework deleted")
    end
  end
end
