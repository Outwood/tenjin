# frozen_string_literal: true

# Aggregates platform usage statistics, optionally scoped to a single school.
# Constructed cheaply; each method runs its query once and memoizes the result.
class School::Statistics
  def initialize(school = nil)
    @school = school
  end

  def asked_questions_last_four_weeks
    @asked_questions_last_four_weeks ||= school_scope(UserStatistic)
      .where(week_beginning: four_weeks_start..)
      .sum(:questions_answered)
  end

  def asked_questions_weekly
    @asked_questions_weekly ||= school_scope(UserStatistic)
      .where(week_beginning: Date.current.beginning_of_week)
      .sum(:questions_answered)
  end

  def homeworks_completed_last_four_weeks
    @homeworks_completed_last_four_weeks ||= school_scope(
      HomeworkProgress.where(completed: true, updated_at: four_weeks_start..)
    ).count
  end

  def homeworks_completed_weekly
    @homeworks_completed_weekly ||= school_scope(
      HomeworkProgress.where(completed: true, updated_at: Date.current.beginning_of_week..Time.current)
    ).count
  end

  def customisation_unlocks_last_four_weeks
    @customisation_unlocks_last_four_weeks ||= school_scope(
      CustomisationUnlock.where(updated_at: four_weeks_start..)
    ).count
  end

  def customisation_unlocks_weekly
    @customisation_unlocks_weekly ||= school_scope(
      CustomisationUnlock.where(updated_at: Date.current.beginning_of_week..Time.current)
    ).count
  end

  private

  # user_statistics is a weekly rollup (one row per user per week_beginning),
  # so every window here aligns to a week boundary rather than a rolling 30 days.
  def four_weeks_start
    3.weeks.ago.to_date.beginning_of_week
  end

  def school_scope(relation)
    return relation if @school.nil?

    relation.joins(user: :school).where(users: {school: @school})
  end
end
