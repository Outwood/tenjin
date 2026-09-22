# frozen_string_literal: true

module System
  # The platform's users, searchable as a directory and shown one at a time.
  class UsersController < BaseController
    # A trust's roster runs to tens of thousands, so the directory is a search
    # rather than a listing
    PER_PAGE = 25

    def index
      directory = User::Directory.new(
        scope: policy_scope(User),
        search: params[:search],
        type: params[:type],
        role: params[:role],
        school: params[:school]
      )
      @pagy, @users = pagy(directory.users, limit: PER_PAGE, page: requested_page)
      @schools = policy_scope(School).order(:name)
    end

    def show
      @user = authorize find_user
      @roles = @user.roles.includes(:resource)
      @classrooms = @user.classrooms.includes(:subject).order(:name)
      @subjects = Subject.where(active: true).order(:name)
    end

    private

    # Pagy refuses a page below the first; like one past the end, it is a typed
    # URL or a stale link rather than an error
    def requested_page = [params[:page].to_i, 1].max

    def find_user = User.find(params[:id])
  end
end
