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
end
