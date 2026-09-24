# frozen_string_literal: true

# One option, accepted text or True/False label belonging to a question
class Answer < ApplicationRecord
  # Generated for the uniqueness constraint alone; Ruby compares through normalise_text
  self.ignored_columns += ["text_key"]

  belongs_to :question
  validates :text, presence: true

  # Stray spacing is never what separates one answer from another; the
  # text_key column repeats this rule in SQL
  def self.normalise_text(text)
    text.to_s.strip.gsub(/\s+/, " ")
  end
end
