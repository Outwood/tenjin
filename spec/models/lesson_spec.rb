# frozen_string_literal: true

require "rails_helper"

YOUTUBE_VALID = [
  %w[www.youtube.com/@OneVoiceChildrensChoir?v=FUQheX3PSnY FUQheX3PSnY],
  %w[www.youtube.com/@Starlight.Lyrics?v=Sr3X0DCXI-M Sr3X0DCXI-M],
  %w[www.youtube.com/@dadimakesmusic?v=VFZNvj-HfBU VFZNvj-HfBU],
  %w[m.youtube.com/watch?v=VFZNvj-HfBU VFZNvj-HfBU],
  %w[www.youtube-nocookie.com/embed/VFZNvj-HfBU VFZNvj-HfBU],
  %w[www.youtube-nocookie.com/embed/VFZNvj-HfBU?autoplay=1 VFZNvj-HfBU],
  %w[www.youtube.com/embed/VFZNvj-HfBU VFZNvj-HfBU],
  %w[www.youtube.com/embed/VFZNvj-HfBU?autoplay=1 VFZNvj-HfBU],
  %w[www.youtube.com/v/VFZNvj-HfBU?fs=1&hl=en_US VFZNvj-HfBU],
  %w[www.youtube.com/watch?v=VFZNvj-HfBU VFZNvj-HfBU],
  %w[youtu.be/VFZNvj-HfBU VFZNvj-HfBU],
  %w[youtu.be/VFZNvj-HfBU?t=120 VFZNvj-HfBU],
  %w[youtube-nocookie.com/embed/VFZNvj-HfBU VFZNvj-HfBU],
  %w[youtube.com/embed/VFZNvj-HfBU VFZNvj-HfBU],
  %w[youtube.com/v/VFZNvj-HfBU?fs=1&hl=en_US VFZNvj-HfBU],
  %w[youtube.com/watch?v=VFZNvj-HfBU VFZNvj-HfBU]
].freeze

VIMEO_VALID = [
  %w[player.vimeo.com/122054187 122054187],
  %w[vimeo.com/122054187 122054187],
  %w[www.vimeo.com/122054187 122054187]
].freeze

SCHEMES = ["", "//", "http://", "https://"].freeze

def prepend_schemes(links, schemes: SCHEMES)
  schemes.product(links).lazy.map { |scheme, (link, result)| ["#{scheme}#{link}", result] }
end

RSpec.describe Lesson do
  it { is_expected.to have_many(:questions) }
  it { is_expected.to belong_to(:topic) }

  it "has a valid factory" do
    expect(build(:lesson)).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_length_of(:title).is_at_least(3) }

    describe "video links" do
      let(:lesson) { build(:lesson) }

      it "accepts a valid YouTube link", :aggregate_failures do
        prepend_schemes(YOUTUBE_VALID).each do |url, _|
          lesson.video_link = url
          expect(lesson).to be_valid
        end
      end

      it "accepts a valid vimeo link", :aggregate_failures do
        prepend_schemes(VIMEO_VALID).each do |url, _|
          lesson.video_link = url
          expect(lesson).to be_valid
        end
      end

      it "rejects other links" do
        lesson.video_link = "badtu.be/VFZNvj-HfBU"
        expect(lesson).not_to be_valid
      end
    end
  end

  describe "moving to another topic" do
    let(:lesson) { create(:lesson) }
    let(:other_topic) { create(:topic, subject: lesson.subject) }

    context "with questions" do
      before { create(:question, topic: lesson.topic, lesson: lesson) }

      it "is refused" do
        lesson.topic = other_topic
        expect(lesson).not_to be_valid
        expect(lesson.errors[:topic]).to contain_exactly("can't change while the lesson has questions")
      end
    end

    context "without questions" do
      it "is allowed" do
        lesson.topic = other_topic
        expect(lesson).to be_valid
      end
    end
  end

  describe "#video_link=" do
    let(:lesson) { described_class.new }

    context "with a matching YouTube URL" do
      it "sets video_id and category" do
        expect { lesson.video_link = "youtu.be/VFZNvj-HfBU" }
          .to change(lesson, :video_id).to("VFZNvj-HfBU")
          .and change(lesson, :category).to("youtube")
      end
    end

    context "with a matching vimeo URL" do
      it "sets video_id and category" do
        expect { lesson.video_link = "vimeo.com/122054187" }
          .to change(lesson, :video_id).to("122054187")
          .and change(lesson, :category).to("vimeo")
      end
    end

    context "with an unsupported URL" do
      it "does not change video_id but sets category to no_content" do
        expect { lesson.video_link = "badtu.be/VFZNvj-HfBU" }
          .not_to change(lesson, :video_id)
        expect(lesson.category).to eq("no_content")
      end
    end
  end

  describe "#video_link" do
    it "returns the given link when one is provided", :aggregate_failures do
      lesson = described_class.new(video_link: YOUTUBE_VALID[0][0])
      allow(lesson).to receive(:video_url)
      expect(lesson.video_link).to eq YOUTUBE_VALID[0][0]
      expect(lesson).not_to have_received(:video_url)
    end

    it "delegates to #video_url when a link is not provided" do
      lesson = described_class.new
      allow(lesson).to receive(:video_url)
      lesson.video_link
      expect(lesson).to have_received(:video_url)
    end

    # The edit form pre-fills the URL field with this value, so the setter must accept it
    it "round-trips through #video_link= for every video category", :aggregate_failures do
      described_class::CATEGORY_VIDEOS.each_key do |category|
        stored = described_class.new(category: category, video_id: "371104836")
        expect(described_class.new(video_link: stored.video_link))
          .to have_attributes(category: category.to_s, video_id: "371104836")
      end
    end
  end

  describe "#video_url" do
    subject { build(:lesson, video_id: vid, category: category).video_url }

    context "with a video_id and youtube category" do
      let(:category) { "youtube" }
      let(:vid) { "abc123" }

      it { is_expected.to include(vid).and include("youtu") }
    end

    context "with a video_id and vimeo category" do
      let(:category) { "vimeo" }
      let(:vid) { "abc123" }

      it { is_expected.to include(vid).and include("vimeo") }
    end

    context "with no_content category" do
      let(:category) { "no_content" }
      let(:vid) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "#thumbnail_url" do
    subject { build(:lesson, video_id: vid, category: category).thumbnail_url }

    context "with a video_id and youtube category" do
      let(:category) { "youtube" }
      let(:vid) { "abc123" }

      it { is_expected.to include(vid).and include("youtu") }
    end

    context "with a video_id and vimeo category" do
      let(:category) { "vimeo" }
      let(:vid) { "abc123" }

      it { is_expected.to be_nil }
    end

    context "with no_content category" do
      let(:category) { "no_content" }
      let(:vid) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "#destroy" do
    it "clears the pointer of a topic that uses it as the default lesson" do
      topic = create(:topic)
      lesson = create(:lesson, topic: topic)
      topic.update!(default_lesson: lesson)

      expect { lesson.destroy! }.to change { topic.reload.default_lesson_id }.from(lesson.id).to(nil)
    end
  end
end
