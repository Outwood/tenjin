# frozen_string_literal: true

require "rails_helper"

RSpec.describe "question flags controller", :default_creates do
  let(:question) { create(:question, topic: topic) }

  before { sign_in student }

  describe "POST /questions/:question_id/flag" do
    subject(:flag) { post question_flag_path(question) }

    it "flags the question" do
      expect { flag }.to change { FlaggedQuestion.exists?(question: question, user: student) }.from(false).to(true)
      expect(response).to have_http_status(:ok)
    end

    context "when the student has already flagged the question" do
      let!(:flagged_question) { create(:flagged_question, user: student, question: question) }

      it "keeps the one flag" do
        expect { flag }.not_to change(FlaggedQuestion, :count)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when a concurrent request flags the question between look-up and save" do
      before do
        allow(FlaggedQuestion).to receive(:find_or_initialize_by).and_wrap_original do |original, **attributes|
          original.call(**attributes).tap { create(:flagged_question, **attributes) }
        end
        flag
      end

      it "answers as already flagged" do
        expect(response).to have_http_status(:ok)
      end

      it "counts the one flag" do
        expect(FlaggedQuestion.where(question: question, user: student).count).to eq 1
        expect(question.reload.flagged_questions_count).to eq 1
      end
    end

    context "when the question does not exist" do
      it "is not found" do
        expect { post question_flag_path(question_id: 0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "DELETE /questions/:question_id/flag" do
    subject(:unflag) { delete question_flag_path(question) }

    context "when the student has flagged the question" do
      let!(:flagged_question) { create(:flagged_question, user: student, question: question) }

      it "takes the flag off" do
        expect { unflag }.to change { FlaggedQuestion.exists?(flagged_question.id) }.from(true).to(false)
        expect(response).to have_http_status(:ok)
      end

      context "when a callback halts the delete" do
        # No callback halts the delete today, so the refusal is stubbed; the
        # branch is what keeps one added later from reading as an unflag
        before do
          allow_any_instance_of(FlaggedQuestion).to receive(:destroy).and_return(false)
          unflag
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

    context "with another student's flag on the question" do
      let!(:other_flag) { create(:flagged_question, user: create(:student, school: school), question: question) }

      it "leaves it in place" do
        expect { unflag }.not_to change(FlaggedQuestion, :count)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
