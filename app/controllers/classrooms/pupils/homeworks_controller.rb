# frozen_string_literal: true

module Classrooms
  module Pupils
    # Sets homework the class already has for one pupil, such as one who joined after it was set.
    # The teacher chooses which: enrolment data can arrive before or after the pupil really joined.
    class HomeworksController < ApplicationController
      before_action :authenticate_user!
      before_action :find_pupil

      def new
        @homeworks = unset_homeworks
      end

      def create
        homeworks = unset_homeworks.where(id: params[:homework_ids])
        if homeworks.empty?
          @homeworks = unset_homeworks
          @error = "Choose at least one homework."
          return render :new, status: :unprocessable_content
        end

        homeworks.each { |homework| homework.assign_to([@pupil.id]) }
        redirect_to classroom_path(@classroom), notice: set_notice(homeworks)
      end

      private

      def find_pupil
        @classroom = Classroom.find(params[:classroom_id])
        authorize Homework.new(classroom: @classroom), :create?
        @pupil = @classroom.users.where(role: :student).find(params[:pupil_id])
      end

      # The class's homework the pupil has no row for, latest due first
      def unset_homeworks
        @classroom.homeworks.where.not(id: HomeworkProgress.where(user: @pupil).select(:homework_id))
          .includes(:topic, :lesson).order(due_date: :desc)
      end

      def set_notice(homeworks)
        what = (homeworks.size == 1) ? "#{homeworks.first.title} homework" : "#{homeworks.size} homework"
        "#{what} set for #{@pupil.forename} #{@pupil.surname}"
      end
    end
  end
end
