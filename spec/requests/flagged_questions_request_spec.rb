# frozen_string_literal: true

require "rails_helper"

RSpec.describe "flagged questions controller", :default_creates do
  subject(:flag) { post flagged_questions_path, params: {flagged_question: {question_id: question_id}} }

  let(:question) { create(:question, topic: topic) }
  let(:question_id) { question.id }

  before { sign_in student }

  describe "POST /flagged_questions" do
    it "flags the question" do
      expect { flag }.to change { FlaggedQuestion.exists?(question: question, user: student) }.from(false).to(true)
      expect(response).to have_http_status(:ok)
    end

    context "when the student has already flagged the question" do
      let!(:flagged_question) { create(:flagged_question, user: student, question: question) }

      it "takes the flag off" do
        expect { flag }.to change { FlaggedQuestion.exists?(flagged_question.id) }.from(true).to(false)
        expect(response).to have_http_status(:ok)
      end

      context "when a callback halts the delete" do
        # No callback halts the delete today, so the refusal is stubbed; the
        # branch is what keeps one added later from reading as an unflag
        before do
          allow_any_instance_of(FlaggedQuestion).to receive(:destroy).and_return(false)
          flag
        end

        it "keeps the flag" do
          expect(FlaggedQuestion.exists?(flagged_question.id)).to be true
        end

        it "says so rather than letting the icon clear" do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).to include("Flag not removed")
        end
      end
    end

    context "when the flag names no question that exists" do
      let(:question_id) { 0 }

      it "flags nothing" do
        expect { flag }.not_to change(FlaggedQuestion, :count)
      end

      it "reports what the record refused" do
        flag
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("Question must exist")
      end
    end
  end
end
