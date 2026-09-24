# frozen_string_literal: true

namespace :asked_questions do
  desc "Count, once each, answers recorded before attempts stored answered_at"
  task count_uncounted: :environment do
    counted = 0

    AskedQuestion.where(answered_at: nil).where.not(correct: nil).includes(:quiz).find_each do |asked_question|
      AskedQuestion.transaction do
        # Setting answered_at marks the row counted, so a rerun skips it
        claimed = AskedQuestion.where(id: asked_question.id, answered_at: nil)
          .update_all(answered_at: asked_question.updated_at) == 1

        if claimed
          Quiz::CountAnswer.call(question_id: asked_question.question_id, user_id: asked_question.quiz.user_id,
            correct: asked_question.correct, answered_at: asked_question.updated_at)
          counted += 1
        end
      end
    end

    puts "counted #{counted} answer(s) recorded before answered_at"
  end
end
