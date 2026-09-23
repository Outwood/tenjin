# frozen_string_literal: true

class FlaggedQuestionPolicy < ApplicationPolicy
  def create?
    true
  end

  def destroy?
    record.user == user
  end
end
