# frozen_string_literal: true

# One pupil's run through the questions of a topic, a lesson or a lucky dip
class Quiz < ApplicationRecord
  LUCKY_DIP = "Lucky Dip"
  # The most questions one quiz asks
  QUESTION_COUNT = 10

  belongs_to :user
  belongs_to :subject
  belongs_to :topic, optional: true
  belongs_to :lesson, optional: true

  has_many :asked_questions, dependent: :delete_all
  has_many :questions, through: :asked_questions
  attr_accessor :picked_subject

  after_create :update_usage_statistics

  scope :for_user, ->(user) { where(user: user) }

  def self.current_for(user)
    scope = for_user(user).where(active: true)
    return nil if scope.empty?
    return scope.first if scope.count == 1

    deactivate_stale_for(user)
    scope.first
  end

  def self.deactivate_stale_for(user)
    for_user(user).where(active: true).order(created_at: :desc).drop(1).each do |quiz|
      if quiz.num_questions_asked.zero?
        quiz.destroy
      else
        quiz.update(active: false)
      end
    end
  end

  private

  def update_usage_statistics
    # The date column is a datetime, which a Date would match only at UTC midnight
    s = UsageStatistic.where(user: user, topic: topic, lesson: lesson, date: Time.current.all_day)
      .first_or_create!(date: Time.current.beginning_of_day)
    s.increment!(:quizzes_started)
  end
end
