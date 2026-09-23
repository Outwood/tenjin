# frozen_string_literal: true

class SchoolsController < ApplicationController
  before_action :authenticate_user!

  def show
    @school = authorize find_school
  end

  private

  def find_school
    School.find(params[:id])
  end
end
