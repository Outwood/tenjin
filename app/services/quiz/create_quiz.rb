# frozen_string_literal: true

# Creates a Quiz session object and initialises it appropriately
class Quiz::CreateQuiz < ApplicationCommand
  def initialize(user:, topic:, subject:, lesson: nil)
    @user = user
    @topic_id = topic
    @subject = subject
    @lesson_id = lesson
    @lucky_dip = @topic_id == Quiz::LUCKY_DIP
    @quiz = Quiz.new
  end

  def call
    return failure("User not found") if @user.blank?
    return failure("Topic not found") unless topic_found?
    return failure("Lesson not found") unless lesson_found?

    initialise_quiz

    @seconds_left = @user.seconds_left_on_cooldown
    return failure({code: :cooldown, seconds_left: @seconds_left}) if @seconds_left.positive?

    initialise_questions
    return failure("No questions are available for this topic") if @quiz.questions.empty?

    @quiz.save!
    @user.time_of_last_quiz = Time.current
    @user.save!
    success(quiz: @quiz)
  end

  private

  # Points go to the question's topic, so it must be inside the credited subject
  def topic_found?
    return true if @lucky_dip

    @topic = @subject.topics.find_by(id: @topic_id)
    @topic.present?
  end

  # Homework progress matches on topic, so a lesson must be inside the chosen topic
  def lesson_found?
    return true if @lucky_dip || @lesson_id.blank?

    @lesson = @topic.lessons.find_by(id: @lesson_id)
    @lesson.present?
  end

  def initialise_quiz
    @quiz.user_id = @user.id
    @quiz.time_last_answered = Time.current
    @quiz.streak = 0
    @quiz.answered_correct = 0
    @quiz.num_questions_asked = 0
    @quiz.subject = @subject
    @quiz.lesson = @lesson
    @quiz.active = true
    @quiz.topic = @lucky_dip ? nil : @topic
    @quiz.counts_for_leaderboard = check_if_quiz_counts_for_leaderboard
  end

  def initialise_questions
    questions = if @lucky_dip
      lucky_dip_questions
    elsif @lesson
      lesson_questions
    else
      subject_questions
    end
    @quiz.questions = questions
    @quiz.question_order = questions.map(&:id).shuffle
  end

  def lucky_dip_questions
    # We want an even distribution of topics where possible
    question_array = []

    # Keep getting random questions, one from each topic until we have a full quiz
    question_array += topic_questions

    if question_array.length < Quiz::QUESTION_COUNT
      # There are fewer topics than a quiz asks questions, so try without getting one from each topic
      question_array += additional_topic_questions
    end

    # A full quiz at most; the additional questions include the one-per-topic picks
    question_array.uniq.sample(Quiz::QUESTION_COUNT)
  end

  def additional_topic_questions
    Question.where(active: true)
      .includes(:topic).references(:topic)
      .select("questions.topic_id, questions.*")
      .where(topics: {active: true, subject_id: @subject.id})
      .order(Arel.sql("questions.topic_id, random()"))
  end

  def topic_questions
    Question.where(active: true)
      .includes(:topic).references(:topic)
      .select("DISTINCT ON(questions.topic_id) questions.topic_id, questions.*")
      .where(topics: {active: true, subject_id: @subject.id})
      .order(Arel.sql("questions.topic_id, random()"))
  end

  def lesson_questions
    Question.where(active: true)
      .includes(:lesson)
      .where(lesson: @lesson)
      .order(Arel.sql("RANDOM()"))
      .take(Quiz::QUESTION_COUNT)
  end

  def subject_questions
    Question.where(active: true, topic: @topic)
      .includes(:topic)
      .order(Arel.sql("RANDOM()"))
      .take(Quiz::QUESTION_COUNT)
  end

  def check_if_quiz_counts_for_leaderboard
    return true if @quiz.topic.nil?

    if @quiz.lesson
      check_lesson_attempts
    else
      check_topic_attempts
    end
  end

  def check_lesson_attempts
    !UsageStatistic.where(user: @user, topic: @quiz.topic, lesson: @quiz.lesson, date: Date.current.all_day)
      .where(quizzes_started: 1..)
      .exists?
  end

  def check_topic_attempts
    !UsageStatistic.where(user: @user, topic: @quiz.topic, date: Date.current.all_day)
      .where(quizzes_started: 3..)
      .exists?
  end
end
