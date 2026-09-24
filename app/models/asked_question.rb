# frozen_string_literal: true

# One question asked in a quiz, with what the pupil answered once they have
class AskedQuestion < ApplicationRecord
  belongs_to :question
  belongs_to :quiz
  belongs_to :answer, optional: true
end
