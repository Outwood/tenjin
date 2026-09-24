# frozen_string_literal: true

# Adds one answered question to the question's and the pupil's statistics
class Quiz::CountAnswer < ApplicationService
  def initialize(question_id:, user_id:, correct:, answered_at:)
    @question_id = question_id
    @user_id = user_id
    @correct = correct
    @answered_at = answered_at
  end

  # Increments in SQL, so pupils answering one question at once lose no count
  def call
    count_for_question
    count_for_user
  end

  private

  # Both counts are nullable columns
  def count_for_question
    QuestionStatistic.upsert_all(
      [{question_id: @question_id, number_asked: 1, number_correct: @correct ? 1 : 0}],
      unique_by: :question_id,
      on_duplicate: Arel.sql(<<~SQL.squish)
        number_asked = COALESCE(question_statistics.number_asked, 0) + 1,
        number_correct = COALESCE(question_statistics.number_correct, 0) + EXCLUDED.number_correct,
        updated_at = EXCLUDED.updated_at
      SQL
    )
  end

  def count_for_user
    UserStatistic.upsert_all(
      [{user_id: @user_id, week_beginning: @answered_at.to_date.beginning_of_week, questions_answered: 1}],
      unique_by: %i[user_id week_beginning],
      on_duplicate: Arel.sql(
        "questions_answered = user_statistics.questions_answered + 1, updated_at = EXCLUDED.updated_at"
      )
    )
  end
end
