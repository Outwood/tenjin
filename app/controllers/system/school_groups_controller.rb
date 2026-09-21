# frozen_string_literal: true

module System
  class SchoolGroupsController < BaseController
    def index
      authorize SchoolGroup, :index?
      @school_groups = policy_scope(SchoolGroup)
    end

    def new
      @school_group = SchoolGroup.new
      authorize @school_group
    end

    def edit
      @school_group = authorize find_school_group
    end

    def create
      @school_group = SchoolGroup.new(school_group_params)
      authorize @school_group

      if @school_group.save
        redirect_to system_school_groups_path, notice: "School group created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @school_group = authorize find_school_group

      if @school_group.update(school_group_params)
        redirect_to system_school_groups_path, notice: "School group updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      school_group = authorize find_school_group

      if school_group.destroy
        redirect_to system_school_groups_path, notice: "School group deleted."
      else
        flash.now[:alert] = school_group.errors.full_messages.to_sentence
        render template: "shared/flash", status: :unprocessable_content
      end
    end

    private

    def find_school_group
      SchoolGroup.find(params[:id])
    end

    def school_group_params
      params.require(:school_group).permit(:name)
    end
  end
end
