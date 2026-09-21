# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Schools::Syncs", :default_creates, type: :request do
  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

  # Capybara.string drops a <template>'s content, so read the stream's markup directly
  def stream_update(target)
    template = Nokogiri::HTML4(response.body).at_css("turbo-stream[action='update'][target='#{target}'] template")
    Capybara.string(template&.inner_html.to_s)
  end

  describe "POST /system/schools/:school_id/sync" do
    before { sign_in super_admin }

    it "queues a sync" do
      expect { post system_school_sync_path(school), headers: turbo_headers }
        .to change { school.reload.sync_status }.from("successful").to("queued")
        .and have_enqueued_job(SyncSchoolJob).with(school)
    end

    it "redraws the sync status as queued" do
      post system_school_sync_path(school), headers: turbo_headers
      expect(stream_update("sync_status_school_#{school.id}")).to have_css(".badge", exact_text: "Queued")
    end

    context "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "refuses" do
        expect { post system_school_sync_path(school) }.not_to change { school.reload.sync_status }
      end
    end
  end
end
