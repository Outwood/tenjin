# frozen_string_literal: true

# One option, accepted text or True/False label belonging to a question
class Answer < ApplicationRecord
  # Created deferrable by AddUniqueAnswerTextPerQuestion
  TEXT_CONSTRAINT = "answers_question_id_text"

  belongs_to :question
  has_many :asked_questions, dependent: :nullify
  validates :text, presence: true

  # Whitespace never tells one answer from another, on screen or to the checker
  normalizes :text, with: ->(text) { text.squish }
end
