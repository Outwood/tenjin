# frozen_string_literal: true

class QuizzesController < ApplicationController
  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :quiz_not_authorized

  def index
    policy_scope(Quiz)
    quiz = Quiz.current_for(current_user)
    redirect_to(quiz || dashboard_path)
  end

  def show
    @quiz = authorize find_quiz
    @question = question_for_quiz(@quiz)
    @multiplier = Multiplier.for_streak(@quiz.streak)
    @percent_complete = (@quiz.num_questions_asked / @quiz.questions.length.to_f) * 100.to_f
    @flagged_question = FlaggedQuestion.where(user: current_user, question: @question).first
    @lesson = lesson_for_question(@question)
    return render :show if @quiz.active?

    percent_correct = calculate_percent_correct(@quiz)

    flash[:notice] = if percent_correct > 60
      "Finished!  You got #{percent_correct}%.  Well done!"
    else
      "Finished!  You got #{percent_correct}%"
    end

    redirect_to dashboard_path
  end

  def new
    @subject = find_subject
    authorize Quiz.new(subject: @subject)

    @topics = @subject.topics.where(active: true)
      .order(:name)
      .pluck(:name, :id)
    @topics.prepend([Quiz::LUCKY_DIP, Quiz::LUCKY_DIP])
    render "select_topic"
  end

  def create
    subject = find_subject
    authorize Quiz.new(subject: subject)
    return redirect_to new_subject_quiz_path(subject) if quiz_params[:topic_id].blank?

    result = Quiz::CreateQuiz.call(user: current_user,
      topic: quiz_params[:topic_id],
      subject: subject,
      lesson: quiz_params[:lesson_id])

    case result
    in {success: true, payload: {quiz:}}
      redirect_to quiz
    in {success: false, error: {code: :cooldown, seconds_left:}}
      flash[:alert] = "You need to wait #{seconds_left} seconds to start another quiz"
      redirect_to dashboard_path
    in {success: false, error:}
      flash[:alert] = error
      redirect_to dashboard_path
    end
  end

  def update
    @quiz = authorize find_quiz
    @question = question_for_quiz(@quiz)

    case Quiz::CheckAnswer.call(quiz: @quiz, question: @question, answer_given: answer_params)
    in {success: true, payload: Quiz::CheckAnswerOutcome => outcome}
      render json: Quiz::AnswerOutcomeSerializer.new(outcome)
    in {success: false, error: :no_answer_provided}
      render json: {error: "No answer provided"}, status: :unprocessable_entity
    end
  end

  private

  def lesson_for_question(question)
    if question.lesson.present?
      question.lesson
    elsif question.topic.default_lesson.present?
      question.topic.default_lesson
    end
  end

  def find_subject
    Subject.find(params[:subject_id])
  end

  def find_quiz
    Quiz.find(params[:id])
  end

  def question_for_quiz(quiz)
    Question.find(quiz.question_order[quiz.num_questions_asked - 1])
  end

  def answer_params
    params.require(:answer).permit(:id, :short_answer)
  end

  def quiz_params
    params.fetch(:quiz, {}).permit(:topic_id, :lesson_id)
  end

  def quiz_not_authorized(exception)
    case exception.query
    when "new?", "create?"
      flash[:alert] = refused_start_message(exception.record.subject)
    when "show?"
      return flash[:alert] = "Quiz does not belong to you" if exception.record.active?
    end
    redirect_to dashboard_path
  end

  def refused_start_message(subject)
    return "Your school does not have access to quizzes" unless current_user.school.permitted?

    "You are not enrolled in #{subject.name}"
  end

  def calculate_percent_correct(quiz)
    return 0 if quiz.answered_correct.blank? || quiz.questions.blank?

    ((quiz.answered_correct / quiz.questions.length.to_f) * 100.to_f).round
  end
end
