# frozen_string_literal: true

FactoryBot.define do
  factory :question do
    sequence(:question_text) { |n| "#{FFaker::Lorem.sentence} #{n}" }
    question_type { "multiple" }
    topic
    active { true }
    lesson { nil }

    # A row saved before question text was required
    trait :without_text do
      question_text { "" }
      to_create { |instance| instance.save!(validate: false) }
    end

    factory :short_answer_question do
      question_type { "short_answer" }
    end

    factory :boolean_question do
      question_type { "boolean" }
      after(:build) do |q|
        q.answers.first.text = "true"
        q.answers << build(:answer, question: q, text: "false")
      end
    end

    factory :question_with_lesson do
      lesson
    end

    after(:build) { |question| question.answers << build(:answer, question: question, correct: true) }
  end
end
