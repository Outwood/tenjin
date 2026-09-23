# frozen_string_literal: true

# Weekly and all-time leaderboards for a subject, or one of its topics, across the viewer's school
class LeaderboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @subjects = policy_scope(current_user.subjects).distinct
  end

  def show
    authorize current_user
    # A topic's board belongs to its own subject, so the subject is never taken separately
    @topic = Topic.find(params[:topic_id]) if params[:topic_id]
    @subject = @topic&.subject || Subject.find(params[:subject_id])

    respond_to do |format|
      format.html { @subjects = current_user.subjects.distinct }
      format.json do
        build_leaderboard
        set_filter_data
        set_user_data
      end
    end
  end

  private

  def build_leaderboard
    @entries = Leaderboard::Query.new(current_user,
      subject: @subject,
      topic: @topic,
      school_group: params[:school_group] == "true",
      all_time: params[:all_time] == "true").results
    @awards = LeaderboardAward.where(school: current_user.school, subject: @subject).group(:user_id).count
    @name = @topic.present? ? @topic.name : @subject.name
    set_classroom_winners
  end

  def subject_classrooms
    @subject_classrooms ||= Classroom.where(school: current_user.school, subject: @subject)
  end

  def set_classroom_winners
    @classroom_winners = ClassroomWinner.joins(:classroom, :user)
      .where(classroom: subject_classrooms)
      .pluck("classrooms.name", "users.forename", "users.surname", :score)
    @classroom_winners.map! { |w| [w[0], "#{w[1]} #{w[2][0]}", w[3]] }
  end

  def set_filter_data
    school_group = current_user.school.school_group
    @schools = if school_group.present?
      school_group.schools.order(:name).pluck(:name)
    else
      [current_user.school.name]
    end
    @classrooms = subject_classrooms.order(:name).pluck(:name)
  end

  def set_user_data
    @user_data = {id: current_user.id,
                  role: current_user.role,
                  school: current_user.school.name,
                  classrooms: current_user.enrollments.joins(:classroom).pluck("classrooms.name")}
  end
end
