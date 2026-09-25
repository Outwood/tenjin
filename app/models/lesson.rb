# frozen_string_literal: true

class Lesson < ApplicationRecord
  LINK_REGEX = [
    [:no_content, /\A[[:blank:]]*\z/],
    [:vimeo, %r{(?:(?:https?:)?//)?(?:www.)?(?:player.)?vimeo.com/(?:[a-z]*/)*(\d+)(?:\S*)}],
    [:youtube,
      %r{(?:(?:https?:)?//)?(?:(?:www|m)\.)?(?:youtube(?:-nocookie)?.com|youtu.be)(?:/(?:[\w\-.@]+\?v=|embed/|v/)?)([\w-]+)(?:\S*)}]
  ].freeze
  CATEGORY_VIDEOS = {
    youtube: "https://www.youtube.com/embed/%s",
    vimeo: "https://player.vimeo.com/video/%s"
  }.freeze
  # Where the edit form points an author: the page they would have copied the link from
  CATEGORY_PAGES = {
    youtube: "https://www.youtube.com/watch?v=%s",
    vimeo: "https://vimeo.com/%s"
  }.freeze
  CATEGORY_THUMBNAILS = {
    youtube: "https://img.youtube.com/vi/%s/hqdefault.jpg"
  }.freeze

  enum :category, {youtube: 0, vimeo: 1, no_content: 2}

  belongs_to :topic
  has_many :homeworks
  has_many :questions
  has_many :quizzes

  has_one :subject, through: :topic

  attribute :video_link, :string

  before_destroy { |record| Question.where(lesson: record).update_all(lesson_id: nil) }

  validates :title, length: {minimum: 3}
  validate :check_video_link
  validate :topic_kept_by_questions, on: :update

  def video_link=(value)
    self.category, self.video_id = extract_id(value)
    super
  end

  def video_link
    super || video_page_url
  end

  def video_url
    format = CATEGORY_VIDEOS[category&.to_sym]
    format && (format % video_id)
  end

  # A question's topic must match its lesson's, so moving the lesson would strand them
  def topic_locked?
    persisted? && questions.exists?
  end

  def thumbnail_url
    format = CATEGORY_THUMBNAILS[category&.to_sym]
    format && (format % video_id)
  end

  private

  def video_page_url
    format = CATEGORY_PAGES[category&.to_sym]
    format && (format % video_id)
  end

  def extract_id(url)
    kind = LINK_REGEX.lazy.filter_map do |c, r|
      (vid = r.match(url)) && [c, vid&.captures&.first]
    end

    kind.first || [:no_content, nil]
  end

  def topic_kept_by_questions
    errors.add :topic, "can't change while the lesson has questions" if topic_id_changed? && topic_locked?
  end

  def check_video_link
    return unless video_link.present? && video_id.nil?

    errors.add :video_link, "must be a YouTube or Vimeo link"
  end
end
