# frozen_string_literal: true

require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe Quiz::CheckAnswer, :default_creates do
  let(:user) { create(:student, school: school) }
  let(:question) { create(:question, topic: topic) }
  let(:correct_answer) { question.answers.find_by(correct: true) }
  let(:wrong_answer) { create(:answer, question: question, correct: false) }
  let(:quiz) { create(:quiz, user: user, question_order: [question.id], num_questions_asked: 1) }

  before do
    quiz.questions << question
    allow(Quiz::AddLeaderboardPoint).to receive(:call)
    allow(Multiplier).to receive(:for_streak).and_return(1)
  end

  it "returns a successful Result with a CheckAnswerOutcome payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(result).to be_success
    expect(result.payload).to be_a(Quiz::CheckAnswerOutcome)
  end

  it "increments streak on a correct multiple-choice answer" do
    initial_streak = quiz.streak
    described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(quiz.reload.streak).to eq(initial_streak + 1)
  end

  it "resets streak on a wrong multiple-choice answer" do
    quiz.update(streak: 4)
    described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id})
    expect(quiz.reload.streak).to eq 0
  end

  it "reports a correct verdict in the payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(result.payload.correct).to be true
  end

  it "reports an incorrect verdict in the payload" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id})
    expect(result.payload.correct).to be false
  end

  it "returns a failure when no answer id is provided for multiple choice" do
    result = described_class.call(quiz: quiz, question: question, answer_given: {id: nil})
    expect(result).to be_failure
    expect(result.error).to eq :no_answer_provided
  end

  describe "the stored answer" do
    let(:asked_question) { quiz.asked_questions.find_by!(question: question) }

    before { described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id}) }

    it "records the option chosen, its text and when" do
      expect(asked_question).to have_attributes(
        correct: false,
        answer_id: wrong_answer.id,
        response: {"text" => wrong_answer.text},
        answered_at: be_within(1.minute).of(Time.current)
      )
    end
  end

  it "counts the answer for the question and the pupil" do
    described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id})
    expect(QuestionStatistic.find_by!(question: question)).to have_attributes(number_asked: 1, number_correct: 1)
    expect(UserStatistic.find_by!(user: user, week_beginning: Date.current.beginning_of_week).questions_answered).to eq 1
  end

  context "with a verdict recorded before answered_at existed" do
    before { quiz.asked_questions.find_by!(question: question).update!(correct: true) }

    it "neither claims nor counts it again" do
      expect { described_class.call(quiz: quiz, question: question, answer_given: {id: wrong_answer.id}) }
        .to not_change { [quiz.reload.num_questions_asked, quiz.asked_questions.pick(:correct, :answered_at)] }
        .and not_change(QuestionStatistic, :count)
    end
  end

  context "with a quiz that counts for the leaderboard" do
    subject(:check) { described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id}) }

    let(:quiz) do
      create(:quiz, user: user, question_order: [question.id], num_questions_asked: 1, counts_for_leaderboard: true)
    end

    before do
      allow(Quiz::AddLeaderboardPoint).to receive(:call).and_call_original
      allow(Leaderboard::BroadcastLeaderboardPoint).to receive(:call)
    end

    it "broadcasts the point once the answer is saved" do
      check
      expect(Leaderboard::BroadcastLeaderboardPoint).to have_received(:call).with(topic, user)
    end

    context "when the same answer is submitted twice at once" do
      # Built before the first lands, as a racing request loads its state
      let!(:late_submission) do
        described_class.new(quiz: Quiz.find(quiz.id), question: question, answer_given: {id: correct_answer.id})
      end

      before { check }

      it "awards the point once" do
        expect { late_submission.call }.not_to change { TopicScore.find_by!(user: user, topic: topic).score }
      end
    end

    context "when the quiz cannot be saved" do
      before { quiz.subject = nil }

      it "raises rather than reporting a score the server does not hold" do
        expect { check }.to raise_error(ActiveRecord::RecordInvalid, /Subject must exist/)
      end

      context "after the refusal" do
        before do
          check
        rescue ActiveRecord::RecordInvalid
        end

        it "leaves the question unanswered, so a retry scores it" do
          expect(quiz.asked_questions.where(question: question).pluck(:correct)).to all(be_nil)
        end

        it "adds no leaderboard point" do
          expect(TopicScore.where(user: user, topic: topic)).to be_empty
        end

        it "broadcasts nothing" do
          expect(Leaderboard::BroadcastLeaderboardPoint).not_to have_received(:call)
        end

        it "counts nothing" do
          expect(QuestionStatistic.where(question: question)).to be_empty
          expect(UserStatistic.where(user: user)).to be_empty
        end
      end
    end
  end

  context "when another answer to the question lands first" do
    let(:quiz) { create(:quiz, user: user, question_order: [question.id], num_questions_asked: 1, streak: 0, answered_correct: 0) }

    # Built before the first lands, as a racing request loads its state
    let!(:late_submission) do
      described_class.new(quiz: Quiz.find(quiz.id), question: question, answer_given: {id: wrong_answer.id})
    end

    before { described_class.call(quiz: quiz, question: question, answer_given: {id: correct_answer.id}) }

    it "reports the verdict of the first" do
      expect(late_submission.call.payload).to have_attributes(correct: true, streak: 1, answered_correct: 1)
    end

    it "leaves the question and quiz as the first left them" do
      expect { late_submission.call }
        .not_to change { [quiz.reload.attributes.values_at("num_questions_asked", "streak", "answered_correct"), quiz.asked_questions.pluck(:correct)] }
    end

    it "counts the question once" do
      expect { late_submission.call }.not_to change { QuestionStatistic.find_by!(question: question).number_asked }
    end
  end

  context "with a correct answer to another question" do
    subject(:check) { described_class.call(quiz: quiz, question: question, answer_given: {id: foreign_answer.id}) }

    let(:other_question) { create(:question, topic: topic) }
    let(:foreign_answer) { other_question.answers.find_by!(correct: true) }

    it "refuses it as no answer" do
      expect(check).to be_failure
      expect(check.error).to eq :no_answer_provided
    end

    it "leaves the question unanswered" do
      check
      expect(quiz.asked_questions.where(question: question).pluck(:correct)).to all(be_nil)
    end

    it "does not move the quiz on" do
      expect { check }.not_to change { quiz.reload.num_questions_asked }
    end
  end

  context "with a short-answer question" do
    let(:short_answer_question) { create(:short_answer_question, topic: topic) }
    let(:quiz) { create(:quiz, user: user, question_order: [short_answer_question.id], num_questions_asked: 1) }

    before { quiz.questions << short_answer_question }

    it "increments streak on a match ignoring case" do
      answer = short_answer_question.answers.find_by!(correct: true)
      expect {
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: answer.text.upcase})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "ignores surrounding and repeated whitespace" do
      answer = short_answer_question.answers.find_by!(correct: true)
      padded = "  #{answer.text.gsub(" ", "   ")}\t"
      expect {
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: padded})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "matches an answer typed with non-breaking spaces" do
      answer = short_answer_question.answers.find_by!(correct: true)
      expect {
        described_class.call(quiz: quiz, question: short_answer_question,
          answer_given: {short_answer: answer.text.tr(" ", "\u00A0")})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "matches an accepted text stored without normalising" do
      # Raw SQL, since any write through the model normalises
      Answer.connection.execute("UPDATE answers SET text = ' Max  Jones ' WHERE question_id = #{short_answer_question.id}")
      expect {
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: "max jones"})
      }.to change { quiz.reload.streak }.by(1)
    end

    it "resets streak on a miss" do
      quiz.update(streak: 3)
      described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: "not it"})
      expect(quiz.reload.streak).to eq 0
    end

    it "treats a blank submission as a wrong answer (success result, streak reset to 0)" do
      quiz.update(streak: 3)
      result = described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: ""})
      expect(result).to be_success
      expect(quiz.reload.streak).to eq 0
    end

    context "with an answer flagged incorrect" do
      let!(:rejected_answer) { create(:answer, question: short_answer_question, correct: false, text: "Ode to Autumn") }

      it "does not accept it" do
        quiz.update(streak: 3)
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: rejected_answer.text})
        expect(quiz.reload.streak).to eq 0
      end
    end

    context "with several accepted answers" do
      let!(:other_answer) { create(:answer, question: short_answer_question, correct: true, text: "The Autumn") }

      it "marks a submission matching any of them correct" do
        expect {
          described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: other_answer.text})
        }.to change { quiz.reload.streak }.by(1)
      end
    end

    describe "the stored answer" do
      let(:asked_question) { quiz.asked_questions.find_by!(question: short_answer_question) }

      before do
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: typed})
      end

      context "with extra spaces typed" do
        let(:typed) { "  Some  guess " }

        it "records the text as typed, with no option" do
          expect(asked_question).to have_attributes(answer_id: nil, response: {"text" => "  Some  guess "})
        end
      end

      context "with a blank answer" do
        let(:typed) { "" }

        it "records it and judges it wrong" do
          expect(asked_question).to have_attributes(response: {"text" => ""}, correct: false, answered_at: be_present)
        end
      end

      context "with an answer as long as the field allows" do
        let(:typed) { "a" * described_class::MAX_RESPONSE_LENGTH }

        it "records it" do
          expect(asked_question.answered_at).to be_present
        end
      end
    end

    context "with an answer longer than the field allows" do
      subject(:check) do
        described_class.call(quiz: quiz, question: short_answer_question,
          answer_given: {short_answer: "a" * (described_class::MAX_RESPONSE_LENGTH + 1)})
      end

      it "refuses it as no answer" do
        expect(check.error).to eq :no_answer_provided
      end

      it "leaves the question unanswered" do
        check
        expect(quiz.asked_questions.find_by!(question: short_answer_question).answered_at).to be_nil
      end
    end

    context "with an answer containing a NUL character" do
      subject(:check) do
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: "a\u0000b"})
      end

      it "refuses it as no answer" do
        expect(check.error).to eq :no_answer_provided
      end
    end

    context "with a question that accepts no text" do
      # Built before the first lands, as a racing request loads its state
      let!(:late_submission) do
        described_class.new(quiz: Quiz.find(quiz.id), question: short_answer_question, answer_given: {short_answer: "later"})
      end

      before do
        Answer.where(question: short_answer_question).delete_all
        described_class.call(quiz: quiz, question: short_answer_question, answer_given: {short_answer: "anything"})
      end

      it "records the answer without a verdict" do
        expect(quiz.asked_questions.find_by!(question: short_answer_question))
          .to have_attributes(correct: nil, answered_at: be_present, response: {"text" => "anything"})
      end

      it "moves the quiz on once" do
        expect { late_submission.call }.not_to change { quiz.reload.num_questions_asked }
      end
    end
  end
end
