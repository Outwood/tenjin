# frozen_string_literal: true

require "rails_helper"

RSpec.describe Homework::RebaseSummerDueTimes do
  include ActiveSupport::Testing::TimeHelpers

  # A due time saved before the release holds the typed clock time as UTC: 09:00 typed is 09:00 UTC
  let(:typed_nine_in_summer) { Time.utc(2026, 9, 8, 9) }
  let(:release) { Time.utc(2026, 9, 1, 12) }
  let(:options) { {} }
  let(:counts) { described_class.call(cutoff: release, **options) }

  before { travel_to release - 1.day }

  def saved_before_release(due_date, **attributes)
    create(:homework, :overdue, due_date: due_date, **attributes)
  end

  context "with an upcoming homework typed in British Summer Time" do
    let!(:homework) { saved_before_release(typed_nine_in_summer) }

    before { travel_to release + 1.hour }

    context "when applied" do
      let(:options) { {apply: true} }

      it "moves it back to the time typed on UK clocks" do
        counts
        expect(homework.reload.due_date).to eq Time.utc(2026, 9, 8, 8)
      end

      it "counts it as upcoming" do
        expect(counts).to include(upcoming: 1, past: 0, moved: 1)
      end

      it "leaves it alone on a second run" do
        described_class.call(cutoff: release, apply: true)
        expect { counts }.not_to change { homework.reload.due_date }
      end
    end

    context "when not applied" do
      it "counts it without moving it" do
        expect(counts).to include(upcoming: 1, moved: 0)
        expect(homework.reload.due_date).to eq typed_nine_in_summer
      end
    end
  end

  context "with an upcoming homework typed in winter" do
    let!(:homework) { saved_before_release(Time.utc(2026, 12, 7, 9)) }
    let(:options) { {apply: true} }

    before { travel_to release + 1.hour }

    it "leaves it alone, since UK and UTC clocks agree" do
      expect(counts).to include(upcoming: 0, moved: 0)
      expect(homework.reload.due_date).to eq Time.utc(2026, 12, 7, 9)
    end
  end

  context "with a homework saved after the release" do
    let(:options) { {apply: true} }
    let!(:homework) do
      travel_to(release + 1.hour) { create(:homework, due_date: Time.utc(2026, 9, 8, 8)) }
    end

    before { travel_to release + 2.hours }

    it "leaves it alone, since it already holds the right time" do
      expect(counts).to include(upcoming: 0, moved: 0)
      expect(homework.reload.due_date).to eq Time.utc(2026, 9, 8, 8)
    end
  end

  context "with a homework already due" do
    let!(:homework) { saved_before_release(typed_nine_in_summer) }

    # 08:30 UTC is 09:30 on UK clocks: late for the time typed, on time for the time stored
    before do
      create(:homework_progress, homework: homework, completed_at: Time.utc(2026, 9, 8, 8, 30))
      travel_to Time.utc(2026, 9, 10)
    end

    context "when applied without the past" do
      let(:options) { {apply: true} }

      it "leaves it alone, and counts the completion that would turn late" do
        expect(counts).to include(past: 1, moved: 0, past_turning_late: 1)
        expect(homework.reload.due_date).to eq typed_nine_in_summer
      end
    end

    context "when applied with the past" do
      let(:options) { {apply: true, include_past: true} }

      it "moves it back" do
        expect(counts).to include(past: 1, moved: 1, past_turning_late: 1)
        expect(homework.reload.due_date).to eq Time.utc(2026, 9, 8, 8)
      end
    end
  end
end
