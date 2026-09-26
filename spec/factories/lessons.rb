# frozen_string_literal: true

FactoryBot.define do
  factory :lesson do
    category { "youtube" }
    title { FFaker::BaconIpsum.sentence }
    video_id { FFaker::Youtube.video_id }
    topic

    # Enough active questions to set as homework
    trait :fills_a_quiz do
      after(:create) { |lesson| create_list(:question, Quiz::QUESTION_COUNT, lesson: lesson, topic: lesson.topic) }
    end
  end
end
