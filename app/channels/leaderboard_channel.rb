# frozen_string_literal: true

# Streams live leaderboard points for a subject to the viewer's school, or its school group
class LeaderboardChannel < ApplicationCable::Channel
  def self.leaderboard_for(subject_id, school)
    ["subject-#{subject_id}", school.leaderboard_scope]
  end

  def subscribed
    subject = Subject.find_by(id: params[:subject_id])
    return reject unless subject && SubjectPolicy.new(current_user, subject).leaderboard?

    stream_for self.class.leaderboard_for(subject.id, current_user.school)
  end
end
