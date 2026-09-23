# frozen_string_literal: true

require "rails_helper"

RSpec.describe "question flag resets controller", :default_creates do
  let(:author) { create(:question_author, subject: quiz_subject) }

  describe "POST /questions/:question_id/flag_reset" do
    let(:question) { create(:question, topic: topic) }
    let!(:flag) { create(:flagged_question, question: question, user: student) }

    before { sign_in author }

    it "clears the question's flags" do
      expect { post question_flag_reset_path(question) }
        .to change { question.reload.flagged_questions_count }.from(1).to(0)
      expect(response).to redirect_to(edit_question_path(question))
    end

    context "when not authorized for the question's subject" do
      let(:author) { create(:question_author, subject: create(:subject)) }

      it "keeps the flags and redirects with an alert" do
        expect { post question_flag_reset_path(question) }.not_to change(FlaggedQuestion, :count)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized to perform this action.")
      end
    end
  end
end
