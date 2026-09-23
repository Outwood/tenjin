# frozen_string_literal: true

module SessionHelpers
  def log_in
    sign_in student
    visit root_path
    expect(page).to have_content("START A QUIZ")
  end

  def stub_wonde_omniauth
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:wonde] =
      OmniAuth::AuthHash.new(
        "provider" => "wonde",
        "uid" => "wonde-user-id-123",
        "info" => {
          "first_name" => "Test",
          "last_name" => "User",
          "upi" => "test-upi",
          "person_type" => "Student",
          "school_id" => "wonde-school-id",
          "school_name" => "Test School"
        },
        "credentials" => {"token" => "fake-wonde-token", "expires" => false},
        "extra" => {}
      )
  end

  def setup_subject_database
    create(:enrollment, classroom: classroom, user: student)
    create(:multiplier)
  end

  def navigate_to_quiz
    visit(new_subject_quiz_path(quiz_subject))
    select Topic.last.name, from: "quiz_topic_id"
    click_button("Create Quiz")
  end

  def navigate_to_lucky_dip
    visit(new_subject_quiz_path(quiz_subject))
    select "Lucky Dip", from: "quiz_topic_id"
    click_button("Create Quiz")
  end

  def create_homework
    find("input#homework_due_date").click
    find(flatpickr_one_week_from_now).click
    select "70", from: "Required %"
    select topic.name, from: "Topic"
  end

  def create_homework_for_lesson
    find("input#homework_due_date").click
    find(flatpickr_one_week_from_now).click
    select "70", from: "Required %"
    select topic.name, from: "Topic"
    select lesson.title, from: "Lesson"
  end

  def flatpickr_one_week_from_now
    "span.flatpickr-day[aria-label=\"#{1.week.from_now.strftime("%B %-e, %Y")}\"]"
  end

  def initialize_name(user)
    "#{user.forename} #{user.surname[0]}"
  end

  def create_file_blob(filename:, content_type:, metadata: nil)
    ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename,
      content_type: content_type, metadata: metadata
  end
end
