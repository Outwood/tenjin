# frozen_string_literal: true

module System
  module Schools
    # A school's employees, and the roles they hold.
    class StaffController < BaseController
      def index
        @school = School.find(params[:school_id])
        authorize @school, policy_class: System::Schools::StaffPolicy

        @employees = policy_scope(User)
          .where(school: @school, role: :employee)
          .order(:surname, :forename)
        @subjects = Subject.where(active: true).order(:name)
      end
    end
  end
end
