# frozen_string_literal: true

require "rails_helper"

RSpec.describe "using a quiz" do
  let!(:student) { create(:student, school: school) }
  let(:question) { create(:question, topic: topic) }
  let(:quiz_subject) { create(:subject) }
  let(:school) { create(:school) }
  let(:topic) { create(:topic, subject: quiz_subject) }
  before do
    sign_in student
  end

  context "when navigating to the root quiz path" do
    let!(:quiz) { create(:quiz, user: student) }

    it "redirects to the latest active quiz" do
      get quizzes_path
      expect(response).to redirect_to(quiz)
    end

    context "when I have multiple quizzes" do
      let!(:quiz) { create(:quiz, user: student, created_at: 1.hour.ago) }
      let!(:new_quiz) { create(:quiz, user: student) }

      it "redirects to the most recently created quiz" do
        get quizzes_path
        expect(response).to redirect_to(new_quiz)
      end
    end
  end

  context "when setting up a quiz" do
    it "redirects to dashboard" do
      get new_quiz_path
      expect(response).to redirect_to dashboard_path
    end

    context "when the subject is valid" do
      let!(:enrollment) { create(:enrollment, school: school, user: student) }

      it "renders the topic select page" do
        get new_quiz_path, params: {subject: enrollment.classroom.subject.name}
        expect(response).to have_http_status(:success)
      end
    end

    context "with an inactive topic in the subject" do
      let(:classroom) { create(:classroom, school: school, subject: quiz_subject) }
      let!(:enrollment) { create(:enrollment, school: school, classroom: classroom, user: student) }
      let!(:active_topic) { create(:topic, subject: quiz_subject, name: "Fractions") }
      let!(:inactive_topic) { create(:topic, subject: quiz_subject, name: "Photosynthesis", active: false) }

      before { get new_quiz_path(subject: quiz_subject.name) }

      it "offers only active topics" do
        expect(Capybara.string(response.body))
          .to have_select("quiz_topic_id", options: ["Lucky Dip", "Fractions"])
      end
    end

    context "with an equipped dashboard style" do
      let(:classroom) { create(:classroom, school: school, subject: quiz_subject) }
      let!(:enrollment) { create(:enrollment, school: school, classroom: classroom, user: student) }
      let!(:active_customisation) do
        create(:active_customisation, user: student, customisation: create(:dashboard_customisation, value: "orange"))
      end

      before { get new_quiz_path(subject: quiz_subject.name) }

      it "colours the separator with the style, not the red default" do
        expect(Capybara.string(response.body)).to have_css(".heading-divider[style*='orange']")
          .and have_no_css(".heading-divider[style*='red']")
      end
    end

    context "when the subject is not enrolled by the student" do
      let!(:enrollment) { create(:enrollment, school: school, user: student) }
      let!(:different_subject) { create(:classroom, school: school) }

      it "redirects to dashboard" do
        get new_quiz_path, params: {subject: different_subject.subject.name}
        expect(response).to redirect_to dashboard_path
      end
    end
  end

  context "when selecting a subject that does not exist" do
    subject { get new_quiz_path, params: {subject: "NOSUBJECT"} }

    it { is_expected.to redirect_to(dashboard_path) }

    it "responds with a flash alert" do
      subject
      expect(flash[:alert]).to match(/does not exist/)
    end
  end

  context "when trying to access a quiz" do
    context "when the quiz belongs to another user" do
      let!(:diff_user) { create(:student) }
      let!(:quiz) { create(:new_quiz, user: diff_user, question_order: [question.id]) }

      it "redirects with an alert" do
        get quiz_path(id: quiz.id)
        expect(flash[:alert]).to match(/Quiz does not belong to you/)
      end
    end

    context "when the quiz is finished" do
      let!(:quiz) { create(:new_quiz, user: student, active: false, question_order: [question.id]) }

      it "redirects with a notice" do
        get quiz_path(id: quiz.id)
        expect(flash[:notice]).to match(/Finished!  You got 0%/)
      end
    end
  end

  describe "starting a quiz" do
    subject { post quizzes_path, params: {quiz: {topic_id: topic.id, subject: quiz_subject.id}} }

    let(:classroom) { create(:classroom, school: school, subject: quiz_subject) }
    let!(:enrollment) { create(:enrollment, school: school, classroom: classroom, user: student) }

    before { create(:question, topic: topic) }

    shared_examples "a refused quiz start" do |message|
      it { is_expected.to redirect_to(dashboard_path) }

      it "does not create a quiz" do
        expect { subject }.not_to change(Quiz, :count)
      end

      it "explains the refusal" do
        subject
        expect(flash[:alert]).to match(message)
      end
    end

    it "creates a quiz" do
      expect { subject }.to change(Quiz, :count).by(1)
    end

    it "redirects to the new quiz" do
      subject
      expect(response).to redirect_to(Quiz.last)
    end

    context "with a lucky dip" do
      subject { post quizzes_path, params: {quiz: {topic_id: Quiz::LUCKY_DIP, subject: quiz_subject.id}} }

      it "creates a quiz" do
        expect { subject }.to change(Quiz, :count).by(1)
      end
    end

    context "with no topic" do
      subject { post quizzes_path, params: {quiz: {subject: quiz_subject.id}} }

      it { is_expected.to redirect_to(new_quiz_path(subject: quiz_subject.name)) }
    end

    context "when the subject does not exist" do
      subject { post quizzes_path, params: {quiz: {topic_id: topic.id, subject: 0}} }

      it_behaves_like "a refused quiz start", /does not exist/
    end

    context "when the student is not enrolled in the subject" do
      let(:classroom) { create(:classroom, school: school) }

      it_behaves_like "a refused quiz start", /not enrolled/
    end

    context "when the school is not permitted" do
      let(:school) { create(:school, permitted: false) }

      it_behaves_like "a refused quiz start", /does not have access/
    end

    context "when the topic belongs to another subject" do
      let(:topic) { create(:topic) }

      it_behaves_like "a refused quiz start", /Topic not found/
    end

    context "when the lesson belongs to another topic" do
      subject do
        post quizzes_path, params: {quiz: {topic_id: topic.id, subject: quiz_subject.id, lesson_id: lesson.id}}
      end

      let(:lesson) { create(:lesson) }

      # Questions exist so only the lesson guard can refuse
      before { create_list(:question, 10, topic: lesson.topic, lesson: lesson) }

      it_behaves_like "a refused quiz start", /Lesson not found/
    end

    context "when a quiz was started moments ago" do
      before { post quizzes_path, params: {quiz: {topic_id: topic.id, subject: quiz_subject.id}} }

      it_behaves_like "a refused quiz start", /You need to wait/
    end
  end

  context "when displaying a question" do
    let!(:multiplier) { create(:multiplier) }
    let(:quiz) { create(:new_quiz, user: student, question_order: [question.id]) }

    it "renders the multiple choice question" do
      get quiz_path(id: quiz.id)
      expect(response).to have_http_status(:success)
    end

    context "before the question is answered" do
      before { get quiz_path(quiz) }

      it "hides the next question button" do
        expect(Capybara.string(response.body)).to have_css("#nextButton.invisible")
      end
    end

    context "when the question has no lesson but its topic has a default lesson" do
      let(:lesson) { create(:lesson, topic: topic, title: "Photosynthesis") }

      before do
        topic.update!(default_lesson: lesson)
        get quiz_path(quiz)
      end

      it "shows the default lesson" do
        expect(Capybara.string(response.body)).to have_css("#lesson h3", text: "Photosynthesis")
      end
    end

    context "when neither the question nor its topic has a lesson" do
      before { get quiz_path(quiz) }

      it "shows no lesson" do
        expect(Capybara.string(response.body)).to have_no_css("#lesson")
      end
    end

    context "when the question has its own lesson" do
      let(:lesson) { create(:lesson, topic: topic, title: "Cell division") }
      let(:question) { create(:question, topic: topic, lesson: lesson) }

      before { get quiz_path(quiz) }

      it "shows the lesson with its video" do
        expect(Capybara.string(response.body)).to have_css("#lesson h3", text: "Cell division")
          .and have_css("#lesson .videoLink")
      end
    end

    context "when the question's lesson has no content" do
      let(:lesson) { create(:lesson, topic: topic, category: "no_content", video_id: "") }
      let(:question) { create(:question, topic: topic, lesson: lesson) }

      before { get quiz_path(quiz) }

      it "shows no lesson" do
        expect(Capybara.string(response.body)).to have_no_css("#lesson")
      end
    end

    context "when the question text includes an image" do
      let(:image) do
        ActiveStorage::Blob.create_and_upload!(io: file_fixture("computer-science.jpg").open,
          filename: "computer-science.jpg", content_type: "image/jpeg")
      end
      let(:question) do
        create(:question, topic: topic,
          question_text: %(<action-text-attachment sgid="#{image.attachable_sgid}"></action-text-attachment><p>Test message</p>))
      end

      before { get quiz_path(quiz) }

      it "renders the image" do
        expect(Capybara.string(response.body)).to have_css('img[src$="computer-science.jpg"]')
      end
    end

    context "when the student has not flagged the question" do
      before { get quiz_path(quiz) }

      it "shows the unfair flag unset" do
        expect(Capybara.string(response.body)).to have_css("#unfairFlag i.far.fa-flag")
      end
    end

    context "when the student has already flagged the question" do
      let!(:flagged_question) { create(:flagged_question, user: student, question: question) }

      before { get quiz_path(quiz) }

      it "shows the unfair flag set" do
        expect(Capybara.string(response.body)).to have_css("#unfairFlag i.fas.fa-flag")
      end
    end

    context "when the quiz counts for the leaderboard" do
      before { get quiz_path(quiz) }

      it "shows no warning" do
        expect(Capybara.string(response.body)).to have_no_css(".alert-warning", text: "not counting")
      end
    end

    context "when the quiz does not count for the leaderboard" do
      let(:quiz) { create(:new_quiz, user: student, question_order: [question.id], counts_for_leaderboard: false) }

      before { get quiz_path(quiz) }

      it "warns that the quiz is not counting" do
        expect(Capybara.string(response.body)).to have_css(".alert-warning", text: "not counting")
      end
    end

    context "when the question is a short answer" do
      let(:short_answer_question) { create(:short_answer_question) }
      let(:quiz) { create(:new_quiz, user: student, question_order: [short_answer_question.id]) }

      it "renders the short answer question" do
        get quiz_path(id: quiz.id)
        expect(response).to have_http_status(:success)
      end
    end
  end
  describe "answering a question" do
    let!(:multiplier) { create(:multiplier) }
    let(:quiz) { create(:new_quiz, user: student, question_order: [question.id]) }
    let(:correct_answer) { question.answers.find_by!(correct: true) }

    before { quiz.questions << question }

    it "awards a leaderboard point for a correct answer" do
      expect { put quiz_path(quiz), params: {answer: {id: correct_answer.id}} }
        .to change { TopicScore.find_by(user: student, topic: topic)&.score }.from(nil).to(1)
    end

    context "when the quiz does not count for the leaderboard" do
      let(:quiz) { create(:new_quiz, user: student, question_order: [question.id], counts_for_leaderboard: false) }
      let!(:prior_score) { create(:topic_score, user: student, topic: topic, score: 3) }

      it "leaves the leaderboard score unchanged" do
        expect { put quiz_path(quiz), params: {answer: {id: correct_answer.id}} }
          .not_to change { prior_score.reload.score }
      end
    end

    context "when the answer earns a multiplier" do
      let!(:doubling_multiplier) { create(:multiplier, score: 1, multiplier: 2) }

      before { put quiz_path(quiz, format: :json), params: {answer: {id: correct_answer.id}}, xhr: true }

      it "returns the updated streak, correct count and multiplier" do
        expect(response.parsed_body).to include("streak" => 1, "answeredCorrect" => 1, "multiplier" => 2)
      end
    end

    # The quiz serves the last id in question_order first
    context "with a further question to answer" do
      let(:second_question) { create(:question, topic: topic) }
      let(:quiz) { create(:new_quiz, user: student, question_order: [second_question.id, question.id]) }
      let!(:doubling_multiplier) { create(:multiplier, score: 1, multiplier: 2) }

      before do
        quiz.questions << second_question
        put quiz_path(quiz), params: {answer: {id: correct_answer.id}}
        get quiz_path(quiz)
      end

      it "shows the updated streak, correct count, multiplier and progress" do
        expect(Capybara.string(response.body)).to have_css("#streak", exact_text: "1")
          .and have_css("#answeredCorrect", exact_text: "1")
          .and have_css("#multiplier", exact_text: "2")
          .and have_css(".progress-bar[aria-valuenow='50.0']")
      end
    end

    context "with a correct answer to another question" do
      let(:other_question) { create(:question, topic: topic) }
      let(:foreign_answer) { other_question.answers.find_by!(correct: true) }

      it "refuses it" do
        put quiz_path(quiz), params: {answer: {id: foreign_answer.id}}
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "awards no leaderboard point" do
        expect { put quiz_path(quiz), params: {answer: {id: foreign_answer.id}} }
          .not_to change { TopicScore.find_by(user: student, topic: topic)&.score }.from(nil)
      end
    end
  end
end
