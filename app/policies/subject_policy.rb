# frozen_string_literal: true

class SubjectPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  # Staff may see any subject's board for their school; pupils only their own subjects'
  def leaderboard?
    user.employee? || user.school_admin? || user.subjects.include?(record)
  end

  def flagged_questions?
    user.has_role? :question_author, record
  end
end
