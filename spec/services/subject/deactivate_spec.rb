# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subject::Deactivate, :default_creates do
  subject(:deactivate) { described_class.call(quiz_subject) }

  let!(:enrollment) { create(:enrollment, user: student, classroom: classroom) }

  it "deactivates the subject" do
    deactivate
    expect(quiz_subject.reload).not_to be_active
  end

  it "unenrols everyone from its classes" do
    expect { deactivate }.to change(Enrollment, :count).by(-1)
  end

  it "leaves its classes without a subject" do
    deactivate
    expect(classroom.reload.subject_id).to be_nil
  end
end
