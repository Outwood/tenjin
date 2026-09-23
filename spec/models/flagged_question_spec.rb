# frozen_string_literal: true

require "rails_helper"

RSpec.describe FlaggedQuestion do
  it "has a valid factory" do
    expect(build(:flagged_question)).to be_valid
  end

  it "refuses a second flag from the same student on a question" do
    flag = create(:flagged_question)

    expect { create(:flagged_question, question: flag.question, user: flag.user) }
      .to raise_error(ActiveRecord::RecordNotUnique, /index_flagged_questions_on_question_id_and_user_id/)
  end
end
