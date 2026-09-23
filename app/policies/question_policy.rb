# frozen_string_literal: true

class QuestionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(topic: TopicPolicy::Scope.new(user, Topic).resolve)
    end
  end

  def update?
    user.has_role? :question_author, record.topic.subject
  end

  alias_method :create?, :update?
  alias_method :destroy?, :update?
end
