# frozen_string_literal: true

module System
  module Subjects
    # Takes a subject out of use, and puts it back.
    class ActivationsController < BaseController
      def create
        subject = authorize find_subject, policy_class: System::Subjects::ActivationPolicy
        subject.update!(active: true)
        redirect_to system_subjects_path
      end

      def destroy
        subject = authorize find_subject, policy_class: System::Subjects::ActivationPolicy
        Subject::Deactivate.call(subject)
        redirect_to system_subjects_path
      end

      private

      def find_subject = Subject.find(params[:subject_id])
    end
  end
end
