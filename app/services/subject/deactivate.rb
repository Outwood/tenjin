# frozen_string_literal: true

# Takes a subject out of use, dropping the enrolments and class links that depend on it.
class Subject::Deactivate < ApplicationService
  def initialize(subject)
    @subject = subject
  end

  def call
    Subject.transaction do
      @subject.update!(active: false)
      enrollments.destroy_all
      Classroom.where(subject: @subject).update_all(subject_id: nil)
    end
  end

  private

  def enrollments
    Enrollment.joins(:classroom).where(classrooms: {subject_id: @subject})
  end
end
