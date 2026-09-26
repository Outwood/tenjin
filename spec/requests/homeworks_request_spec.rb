# frozen_string_literal: true

require "rails_helper"

RSpec.describe "homeworks controller", :default_creates do
  before { sign_in teacher }

  describe "GET /classrooms/:classroom_id/homeworks/new" do
    context "with a classroom" do
      let!(:full_lesson) { create(:lesson, :fills_a_quiz, topic: topic) }
      # Ten questions, one of them retired, so a quiz would come up short
      let!(:short_lesson) do
        create(:lesson, topic: topic).tap do |lesson|
          create_list(:question, 9, lesson: lesson, topic: topic)
          create(:question, lesson: lesson, topic: topic, active: false)
        end
      end
      let(:page) { Capybara.string(response.body) }

      before { get new_classroom_homework_path(classroom) }

      it "marks My Classes as the current section" do
        expect(page).to have_css("#navbar-main .nav-link.active[aria-current='true'][href='#{dashboard_path}']", exact_text: "My Classes")
      end

      it "marks the topic required" do
        expect(page).to have_css("label[for='homework_topic_id'] abbr[title='required']")
      end

      it "lists no lessons before a topic is chosen" do
        expect(page).to have_select("Lesson (Optional)", disabled: true, options: ["Whole topic"])
      end

      it "says which lessons can be set" do
        hint = page.find("#homework_lesson_id")["aria-describedby"]
        expect(page).to have_css("##{hint}", exact_text: "Only lessons with at least 10 questions can be set.")
      end

      it "embeds only the picker fields of lessons with at least ten questions" do
        lessons = JSON.parse(page.find("[data-homework-lessons-value]")["data-homework-lessons-value"])
        expect(lessons).to contain_exactly({"id" => full_lesson.id, "topic_id" => topic.id, "title" => full_lesson.title})
      end
    end

    context "with topics that differ in their questions" do
      let!(:asked_topic) { create(:topic, subject: quiz_subject, name: "Fractions") }
      let!(:retired_topic) { create(:topic, subject: quiz_subject, name: "Decimals") }
      let!(:inactive_topic) { create(:topic, subject: quiz_subject, name: "Percentages", active: false) }

      before do
        create(:question, topic: asked_topic)
        create(:question, topic: retired_topic, active: false)
        create(:question, topic: inactive_topic)
        get new_classroom_homework_path(classroom)
      end

      it "offers each topic with an active question, inactive or not" do
        expect(Capybara.string(response.body))
          .to have_select("Topic", options: ["Choose a topic", "Fractions", "Percentages"])
      end
    end

    context "when the form opens between the picker's five-minute steps" do
      include ActiveSupport::Testing::TimeHelpers

      # 14:08:24 on the teacher's clock, in British Summer Time
      before do
        travel_to Time.utc(2030, 10, 1, 13, 8, 24)
        get new_classroom_homework_path(classroom)
      end

      it "sets it due a week on, to the nearest five minutes" do
        expect(Capybara.string(response.body)).to have_field("homework[due_date]", with: "2030-10-08 14:10")
      end
    end
  end

  describe "POST /classrooms/:classroom_id/homeworks" do
    let(:homework_params) { {topic_id: topic.id, due_date: 1.week.from_now, required: 70} }

    context "with a due time typed in British Summer Time" do
      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(due_date: "2030-07-01 09:00")} }

      it "sets it due at that time on UK clocks" do
        expect(Homework.sole.due_date).to eq Time.utc(2030, 7, 1, 8)
      end
    end

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

    context "with another subject's topic" do
      it "sets no homework and says the topic is outside the class" do
        expect { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(topic_id: create(:topic).id)} }
          .not_to change(Homework, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body)).to have_css("#homework_topic_error", exact_text: "Topic isn't one of this class's topics")
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

    context "with no topic and a due date in the past" do
      let(:page) { Capybara.string(response.body) }

      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(topic_id: "", due_date: 1.day.ago)} }

      it "describes each field with its own error" do
        due_error = page.find("#homework_due_date")["aria-describedby"]
        topic_error = page.find("#homework_topic_id")["aria-describedby"]
        expect(page).to have_css("##{due_error}", exact_text: "Due date can't be in the past")
          .and have_css("##{topic_error}", exact_text: "Topic can't be blank")
      end

      it "describes a field without an error by its hint alone" do
        expect(page).to have_css("#homework_required[aria-describedby='homework_required_hint']")
      end
    end

    context "with a topic that has lost its questions and a due date in the past" do
      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(due_date: 1.day.ago)} }

      it "keeps the chosen topic on offer" do
        expect(Capybara.string(response.body)).to have_select("Topic", selected: topic.name)
      end
    end

    context "with a lesson homework and a due date in the past" do
      let(:lesson) { create(:lesson, :fills_a_quiz, topic: topic, title: "Equivalent fractions") }
      let!(:sibling_lesson) { create(:lesson, :fills_a_quiz, topic: topic, title: "Mixed numbers") }

      before { post classroom_homeworks_path(classroom), params: {homework: homework_params.merge(lesson_id: lesson.id, due_date: 1.day.ago)} }

      it "keeps the chosen lesson among the topic's lessons" do
        expect(Capybara.string(response.body))
          .to have_select("Lesson (Optional)", disabled: false, selected: "Equivalent fractions",
            options: ["Whole topic", "Equivalent fractions", "Mixed numbers"])
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
        homework.homework_progresses.first.update!(completed_at: Time.current)
        get homework_path(homework)
      end

      it "reports the class completion percentage" do
        expect(Capybara.string(response.body)).to have_css("#homework-completion", exact_text: "10% (1 of 10)")
      end

      it "names each pupil's status beside its icon" do
        expect(Capybara.string(response.body))
          .to have_css("tr.student-row td:nth-child(3) i.fa-check", count: 1)
          .and have_css("tr.student-row td:nth-child(3)", exact_text: "Done", count: 1)
          .and have_css("tr.student-row td:nth-child(3)", exact_text: "Not yet due", count: 9)
      end
    end

    context "with a pupil who joined after the homework was set" do
      let!(:homework) { super() }
      let!(:late_enrollment) { create(:enrollment, classroom: classroom, user: student) }
      let(:late_row) { "tr.student-row[data-user='#{student.id}']" }

      before { get homework_path(homework) }

      it "lists them as set before they joined, with no score" do
        expect(Capybara.string(response.body))
          .to have_css("#{late_row} td:nth-child(3)", exact_text: "Set before they joined")
          .and have_css("#{late_row} td:nth-child(4)", exact_text: "")
      end

      it "leaves them out of the completion count" do
        expect(Capybara.string(response.body)).to have_css("#homework-completion", exact_text: "0% (0 of 10)")
      end
    end

    context "with a pupil who has moved to another class" do
      let!(:mover_enrollment) { create(:enrollment, classroom: classroom, user: student) }

      # The move comes after the homework, as a sync would make it, so the mover keeps a completed row on it
      before do
        [enrollments.first.user, student].each { |pupil| homework.homework_progresses.find_by!(user: pupil).update!(completed_at: Time.current) }
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

      it "shows the student's best score" do
        expect(Capybara.string(response.body)).to have_css("tr.student-row td:nth-child(4)", exact_text: "50%", count: 1)
      end
    end

    context "with pupils who share a surname" do
      let(:named_classroom) { create(:classroom, school: school, subject: quiz_subject) }
      let!(:pupils) do
        [%w[Ben Brown], %w[Amelia Brown], %w[Chloe Adams]].map do |forename, surname|
          create(:student, school: school, forename: forename, surname: surname)
            .tap { |pupil| create(:enrollment, classroom: named_classroom, user: pupil) }
        end
      end
      let!(:homework) { create(:homework, classroom: named_classroom) }

      before { get homework_path(homework) }

      it "orders them by forename within the surname" do
        ben, amelia, chloe = pupils
        expect(Capybara.string(response.body))
          .to have_css("tr.student-row:nth-child(1)[data-user='#{chloe.id}']")
          .and have_css("tr.student-row:nth-child(2)[data-user='#{amelia.id}']")
          .and have_css("tr.student-row:nth-child(3)[data-user='#{ben.id}']")
      end

      it "links each first name to the pupil, labelled with the full name" do
        amelia = pupils.second
        expect(Capybara.string(response.body))
          .to have_css("a[href='#{user_path(amelia)}'][aria-label='Amelia Brown']", exact_text: "Amelia")
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

      it "heads the page with the lesson" do
        get homework_path(homework)
        expect(Capybara.string(response.body)).to have_css("h1", exact_text: lesson.title)
      end
    end

    context "with a whole-topic homework" do
      let(:homework) do
        create(:homework, classroom: classroom, topic: topic, required: 70, due_date: Time.zone.local(2030, 10, 5, 9, 0))
      end

      before { get homework_path(homework) }

      it "heads the page with the topic" do
        expect(Capybara.string(response.body)).to have_css("h1", exact_text: topic.name)
      end

      it "lists its topic, pass mark and due time" do
        expect(Capybara.string(response.body).find("#homework-details"))
          .to have_css("dd", exact_text: topic.name)
          .and have_css("dd", exact_text: "Whole topic")
          .and have_css("dd", exact_text: "70% in one quiz")
          .and have_css("dd time[datetime='2030-10-05T09:00+01:00']", exact_text: "5 Oct 2030, 09:00")
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
