# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Subjects", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/subjects" do
    it "renders the index" do
      create(:subject, name: "Maths")
      get system_subjects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maths")
    end

    context "with no deactivated subjects" do
      before { get system_subjects_path }

      it "says so in place of an empty table" do
        expect(Capybara.string(response.body)).to have_text("No deactivated subjects.")
          .and have_no_css("#deactivated-subjects")
      end
    end

    context "with a deactivated subject" do
      let!(:deactivated_subject) { create(:subject, active: false) }

      before { get system_subjects_path }

      it "lists it" do
        expect(Capybara.string(response.body)).to have_css("#deactivated-subjects #subject-#{deactivated_subject.id}")
          .and have_no_text("No deactivated subjects.")
      end
    end
  end

  describe "GET /system/subjects/:id/edit" do
    it "renders the edit form" do
      subject_record = create(:subject, name: "Chemistry")
      get edit_system_subject_path(subject_record)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Chemistry")
    end

    context "with an active subject" do
      let!(:enrollment) { create(:enrollment, classroom: classroom, user: student) }

      before { get edit_system_subject_path(quiz_subject) }

      it "warns how many classes and enrolments deactivation removes" do
        expect(Capybara.string(response.body))
          .to have_css(".callout", text: "1 enrolment across 1 class")
      end

      it "offers deactivation, not reactivation" do
        expect(Capybara.string(response.body))
          .to have_button("Deactivate Subject")
          .and have_no_button("Reactivate Subject")
      end
    end

    context "with a deactivated subject" do
      let(:deactivated_subject) { create(:subject, active: false) }

      before { get edit_system_subject_path(deactivated_subject) }

      it "offers reactivation, not deactivation" do
        expect(Capybara.string(response.body))
          .to have_button("Reactivate Subject")
          .and have_no_button("Deactivate Subject")
          .and have_no_css(".callout")
      end
    end
  end

  describe "POST /system/subjects" do
    it "creates a subject" do
      expect {
        post system_subjects_path, params: {subject: {name: "Biology"}}
      }.to change(Subject, :count).by(1)
    end

    it "redirects to the new subject's edit page" do
      post system_subjects_path, params: {subject: {name: "Botany"}}
      expect(response).to redirect_to(edit_system_subject_path(Subject.find_by!(name: "Botany")))
    end

    it "does not create a subject with a blank name" do
      expect {
        post system_subjects_path, params: {subject: {name: ""}}
      }.not_to change(Subject, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(Capybara.string(response.body)).to have_css(".invalid-feedback", text: "can't be blank")
        .and have_css("h1", exact_text: "Add Subject")
    end
  end

  describe "PATCH /system/subjects/:id" do
    it "updates a subject" do
      subject_record = create(:subject, name: "Physics")
      patch system_subject_path(subject_record), params: {subject: {name: "Astronomy"}}
      expect(subject_record.reload.name).to eq("Astronomy")
    end

    it "leaves the subject's active state alone" do
      expect { patch system_subject_path(quiz_subject), params: {subject: {name: "Astronomy", active: "0"}} }
        .not_to change { quiz_subject.reload.active }.from(true)
    end

    it "redirects to the subject's edit page" do
      patch system_subject_path(quiz_subject), params: {subject: {name: "Astronomy"}}
      expect(response).to redirect_to(edit_system_subject_path(quiz_subject))
    end

    it "does not save an invalid name" do
      subject_record = create(:subject, name: "Geography")
      patch system_subject_path(subject_record), params: {subject: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
      expect(subject_record.reload.name).to eq("Geography")
      expect(Capybara.string(response.body)).to have_css("h1", exact_text: "Geography")
    end
  end

  describe "DELETE /system/subjects/:subject_id/activation" do
    it "deactivates the subject" do
      subject_record = create(:subject)
      delete system_subject_activation_path(subject_record)
      expect(subject_record.reload.active).to be(false)
    end

    it "redirects to the subjects index" do
      delete system_subject_activation_path(quiz_subject)
      expect(response).to redirect_to(system_subjects_path)
    end

    it "detaches the subject from its classrooms" do
      expect { delete system_subject_activation_path(quiz_subject) }
        .to change { classroom.reload.subject }.from(quiz_subject).to(nil)
    end

    context "with a student enrolled in the subject" do
      let!(:enrollment) { create(:enrollment, classroom: classroom, user: student) }

      it "destroys the enrollment" do
        expect { delete system_subject_activation_path(quiz_subject) }
          .to change { classroom.enrollments.count }.from(1).to(0)
      end
    end
  end

  describe "POST /system/subjects/:subject_id/activation" do
    let(:deactivated_subject) { create(:subject, active: false) }

    it "reactivates the subject" do
      expect { post system_subject_activation_path(deactivated_subject) }
        .to change { deactivated_subject.reload.active }.from(false).to(true)
    end

    it "redirects to the subjects index" do
      post system_subject_activation_path(deactivated_subject)
      expect(response).to redirect_to(system_subjects_path)
    end
  end
end
