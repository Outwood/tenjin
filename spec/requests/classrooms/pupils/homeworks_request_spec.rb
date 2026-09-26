# frozen_string_literal: true

require "rails_helper"

RSpec.describe "setting homework for a pupil", :default_creates do
  let(:fractions) { create(:topic, subject: quiz_subject, name: "Fractions") }
  let(:decimals) { create(:topic, subject: quiz_subject, name: "Decimals") }
  let(:percentages) { create(:topic, subject: quiz_subject, name: "Percentages") }
  # Set before the pupil joined, so they have no row on either
  let!(:overdue_homework) { create(:homework, :overdue, classroom: classroom, topic: fractions) }
  let!(:open_homework) { create(:homework, classroom: classroom, topic: decimals) }
  let!(:student_enrollment) { create(:enrollment, classroom: classroom, user: student) }
  # Set after, so they have it already
  let!(:set_homework) { create(:homework, classroom: classroom, topic: percentages) }
  let(:other_class_homework) { create(:homework, classroom: create(:classroom, school: school, subject: quiz_subject)) }
  let(:page) { Capybara.string(response.body) }

  before { sign_in teacher }

  describe "GET /classrooms/:classroom_id/pupils/:pupil_id/homework/new" do
    context "with homework set before the pupil joined" do
      before { get new_classroom_pupil_homework_path(classroom, student) }

      it "offers only the class's homework the pupil does not have" do
        expect(page).to have_unchecked_field("homework_#{overdue_homework.id}")
          .and have_unchecked_field("homework_#{open_homework.id}")
          .and have_no_field("homework_#{set_homework.id}")
      end

      it "marks the homework already past its due date" do
        expect(page).to have_css("label[for='homework_#{overdue_homework.id}'] .badge", exact_text: "Overdue")
          .and have_no_css("label[for='homework_#{open_homework.id}'] .badge")
      end
    end

    context "with every homework already set for the pupil" do
      before do
        [overdue_homework, open_homework].each { |homework| homework.assign_to([student.id]) }
        get new_classroom_pupil_homework_path(classroom, student)
      end

      it "says so instead of offering a form" do
        expect(page).to have_text("already has every homework set for this class")
          .and have_no_css("form[action='#{classroom_pupil_homework_path(classroom, student)}']")
      end
    end

    it "refuses a pupil who is not in the class" do
      outsider = create(:student, school: school)
      expect { get new_classroom_pupil_homework_path(classroom, outsider) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "refuses another school's class" do
      other_classroom = create(:classroom, subject: quiz_subject)
      get new_classroom_pupil_homework_path(other_classroom, student)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end
  end

  describe "POST /classrooms/:classroom_id/pupils/:pupil_id/homework" do
    context "with a homework chosen" do
      before { post classroom_pupil_homework_path(classroom, student), params: {homework_ids: [overdue_homework.id]} }

      it "sets that homework for the pupil and no other" do
        expect(HomeworkProgress.where(user: student).pluck(:homework_id))
          .to contain_exactly(overdue_homework.id, set_homework.id)
      end

      it "returns to the class, naming what was set and for whom" do
        expect(response).to redirect_to(classroom_path(classroom))
        expect(flash[:notice]).to eq("Fractions homework set for #{student.forename} #{student.surname}")
      end
    end

    context "with two homework chosen" do
      before { post classroom_pupil_homework_path(classroom, student), params: {homework_ids: [overdue_homework.id, open_homework.id]} }

      it "counts them in the notice" do
        expect(flash[:notice]).to eq("2 homework set for #{student.forename} #{student.surname}")
      end
    end

    context "with only homework the pupil has or the class lacks" do
      it "sets nothing and asks for a choice" do
        expect { post classroom_pupil_homework_path(classroom, student), params: {homework_ids: [set_homework.id, other_class_homework.id]} }
          .not_to change(HomeworkProgress, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(page).to have_css("[role='alert']", exact_text: "Choose at least one homework.")
      end
    end

    context "with nothing chosen" do
      it "sets nothing and asks for a choice" do
        expect { post classroom_pupil_homework_path(classroom, student) }.not_to change(HomeworkProgress, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(page).to have_css("[role='alert']", exact_text: "Choose at least one homework.")
      end
    end
  end
end
