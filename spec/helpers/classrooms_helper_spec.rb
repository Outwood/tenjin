# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClassroomsHelper do
  describe "#sync_notice" do
    subject(:notice) { helper.sync_notice(school) }

    context "when the school has never synced" do
      let(:school) { build_stubbed(:school, sync_status: :never) }

      it { is_expected.to eq("Never synced. Run the first sync from the school page.") }
    end

    context "when the last sync succeeded" do
      let(:school) { build_stubbed(:school, sync_status: :successful, last_sync: Date.new(2026, 9, 3)) }

      it { is_expected.to eq("Last synced 3 Sep 2026.") }
    end

    context "when the last sync succeeded but carries no date" do
      let(:school) { build_stubbed(:school, sync_status: :successful, last_sync: nil) }

      it { is_expected.to eq("Synced.") }
    end

    context "when a subject change awaits a sync" do
      let(:school) { build_stubbed(:school, sync_status: :needed) }

      it { is_expected.to eq(described_class::SYNC_NEEDED_NOTICE) }
    end

    context "when the last sync failed" do
      let(:school) { build_stubbed(:school, sync_status: :failed) }

      it { is_expected.to eq("Last sync failed.") }
    end

    context "when a sync is queued" do
      let(:school) { build_stubbed(:school, sync_status: :queued) }

      it { is_expected.to eq("Sync running. Refresh the page to see its progress.") }
    end

    context "when a sync is running" do
      let(:school) { build_stubbed(:school, sync_status: :syncing, updated_at: 1.minute.ago) }

      it { is_expected.to eq("Sync running. Refresh the page to see its progress.") }
    end

    context "when a sync has run past its timeout" do
      let(:school) { build_stubbed(:school, sync_status: :syncing, updated_at: School::SYNC_TIMEOUT.ago - 1.minute) }

      it { is_expected.to eq("Last sync timed out.") }
    end
  end

  describe "#homework_due_time" do
    subject(:due_time) { Capybara.string(helper.homework_due_time(build_stubbed(:homework, due_date: due))) }

    context "when due in British Summer Time" do
      let(:due) { Time.utc(2030, 7, 1, 8) }

      it "shows the time on UK clocks, with its offset" do
        expect(due_time).to have_css("time[datetime='2030-07-01T09:00+01:00']", exact_text: "1 Jul 2030, 09:00")
      end
    end

    context "when due in winter" do
      let(:due) { Time.utc(2030, 1, 6, 9) }

      it "shows the time on UK clocks, with its offset" do
        expect(due_time).to have_css("time[datetime='2030-01-06T09:00+00:00']", exact_text: "6 Jan 2030, 09:00")
      end
    end
  end

  describe "#homework_status" do
    subject(:status) { Capybara.string(helper.homework_status(homework, progress)) }

    let(:homework) { build_stubbed(:homework, due_date: Time.zone.local(2026, 9, 24, 9)) }

    context "with the homework completed after its due time" do
      let(:progress) do
        build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 24, 9, 1))
      end

      it "says done late beside an amber tick hidden from screen readers" do
        expect(status).to have_css("i.fa-check.text-warning-emphasis[aria-hidden='true']")
          .and have_text("Done late", exact: true)
      end
    end

    context "with the homework set before the pupil joined" do
      let(:progress) { nil }

      it "says so beside a dash" do
        expect(status).to have_css("i.fa-minus").and have_text("Set before they joined", exact: true)
      end
    end
  end

  describe "#homework_slot" do
    include ActiveSupport::Testing::TimeHelpers

    subject(:slot) { Capybara.string(helper.homework_slot(homework, progress)) }

    let(:topic) { build_stubbed(:topic, name: "Storage") }
    let(:homework) { build_stubbed(:homework, topic: topic, due_date: Time.zone.local(2026, 9, 27, 9)) }

    before { travel_to Time.zone.local(2026, 9, 25, 12) }

    context "with the homework completed" do
      let(:progress) { build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 25, 12)) }

      it "shows a tick labelled done" do
        expect(slot).to have_css("i.fa-check")
          .and have_css(".visually-hidden", exact_text: "Storage, due 27 Sep: done")
      end
    end

    context "with the homework completed after its due time" do
      let(:homework) { build_stubbed(:homework, topic: topic, due_date: Time.zone.local(2026, 9, 24, 9)) }
      let(:progress) do
        build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 24, 9, 1))
      end

      it "shows an amber tick labelled done late" do
        expect(slot).to have_css("i.fa-check.text-warning-emphasis")
          .and have_css(".visually-hidden", exact_text: "Storage, due 24 Sep: done late")
      end
    end

    context "with the homework completed by its due time" do
      let(:progress) do
        build_stubbed(:homework_progress, homework: homework, completed_at: Time.zone.local(2026, 9, 27, 9))
      end

      it "shows a green tick labelled done" do
        expect(slot).to have_css("i.fa-check.text-success")
          .and have_css(".visually-hidden", exact_text: "Storage, due 27 Sep: done")
      end
    end

    context "with the homework not completed and not yet due" do
      let(:progress) { build_stubbed(:homework_progress, homework: homework) }

      it "shows an open circle labelled not yet due" do
        expect(slot).to have_css("i.fa-circle")
          .and have_css(".visually-hidden", exact_text: "Storage, due 27 Sep: not yet due")
      end
    end

    context "with the homework not completed and past its due date" do
      let(:homework) { build_stubbed(:homework, topic: topic, due_date: Time.zone.local(2026, 9, 24, 9)) }
      let(:progress) { build_stubbed(:homework_progress, homework: homework) }

      it "shows an exclamation mark labelled overdue" do
        expect(slot).to have_css("i.fa-exclamation")
          .and have_css(".visually-hidden", exact_text: "Storage, due 24 Sep: overdue")
      end
    end

    context "with the homework set before the pupil joined" do
      let(:progress) { nil }

      it "shows a dash labelled as set before they joined" do
        expect(slot).to have_css("i.fa-minus")
          .and have_css(".visually-hidden", exact_text: "Storage, due 27 Sep: set before they joined")
      end

      it "titles the slot with its label and hides the icon from screen readers" do
        expect(slot).to have_css(".homework-slot[title='Storage, due 27 Sep: set before they joined'] i[aria-hidden='true']")
      end
    end
  end
end
