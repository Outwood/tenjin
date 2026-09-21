# frozen_string_literal: true

module System
  class SubjectsController < BaseController
    def index
      @subjects, @deactivated_subjects = policy_scope(Subject).order(:name).partition(&:active?)
      @question_counts = Question.counts_by_subject
      @subject_statistics = @subjects.each_with_object({}) do |subject, h|
        h[subject.id] = Subject::Statistics.new(subject)
      end
    end

    def edit
      @subject = authorize find_subject
      count_deactivation_losses
    end

    def new
      @subject = Subject.new
      authorize @subject
    end

    def create
      @subject = Subject.new(subject_params)
      authorize @subject

      if @subject.save
        redirect_to edit_system_subject_path(@subject)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @subject = authorize find_subject

      if @subject.update(subject_params)
        redirect_to edit_system_subject_path(@subject)
      else
        count_deactivation_losses
        render :edit, status: :unprocessable_content
      end
    end

    private

    def find_subject
      Subject.find(params[:id])
    end

    def subject_params
      params.require(:subject).permit(:name)
    end

    def count_deactivation_losses
      @classroom_count = @subject.classrooms.count
      @enrollment_count = Enrollment.in_subject(@subject).count
    end
  end
end
