# frozen_string_literal: true

require "rails_helper"

RSpec.describe "schools controller", :default_creates do
  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

  # Capybara.string drops a <template>'s content, so read the stream's markup directly
  def stream_update(target)
    template = Nokogiri::HTML4(response.body).at_css("turbo-stream[action='update'][target='#{target}'] template")
    Capybara.string(template&.inner_html.to_s)
  end

  describe "GET /schools/:id" do
    context "as a school admin of the school" do
      let(:school) { create(:school, last_sync: Date.new(2026, 9, 3)) }

      before do
        sign_in school_admin
        get school_path(school)
      end

      it "offers a sync of the school" do
        expect(Capybara.string(response.body))
          .to have_css("form[action='#{school_sync_path(school)}'] button", exact_text: "Sync Classrooms & Users")
      end

      it "dates the last sync" do
        expect(Capybara.string(response.body)).to have_text("Last synced 3 Sep 2026")
      end

      it "offers the reset of every password behind the confirmation modal" do
        expect(Capybara.string(response.body))
          .to have_button("Reset and print all passwords")
          .and have_css("#resetAllPasswordsModal form[action='#{school_password_reset_path(school)}']", visible: :all)
      end
    end

    context "as a school admin of another school" do
      before do
        sign_in create(:school_admin, school: create(:school))
        get school_path(school)
      end

      it "refuses the page" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as a teacher" do
      before do
        sign_in teacher
        get school_path(school)
      end

      it "refuses the page" do
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /schools/:school_id/sync" do
    context "as a school admin of the school" do
      before { sign_in school_admin }

      it "queues the sync job" do
        expect { post school_sync_path(school) }.to have_enqueued_job(SyncSchoolJob).with(school)
      end

      it "marks the school as queued" do
        expect { post school_sync_path(school) }.to change { school.reload.sync_status }.to("queued")
      end

      it "swaps the sync section for the queued state" do
        post school_sync_path(school), headers: turbo_headers
        expect(stream_update(ActionView::RecordIdentifier.dom_id(school, :sync)))
          .to have_css(".badge", exact_text: "Queued")
          .and have_text(SchoolsHelper::SYNC_REFRESH_MESSAGE)
          .and have_no_button
      end

      it "returns to the school page without Turbo" do
        post school_sync_path(school)
        expect(response).to redirect_to(school_path(school))
      end
    end

    context "as a teacher" do
      before do
        sign_in teacher
        post school_sync_path(school)
      end

      it "leaves the school alone" do
        expect(response).to redirect_to(root_path)
        expect(school.reload.sync_status).to eq("successful")
      end
    end
  end

  describe "POST /schools/:school_id/password_reset" do
    context "as a school admin of the school" do
      before { sign_in school_admin }

      it "queues the password reset job" do
        expect { post school_password_reset_path(school) }.to have_enqueued_job(ResetUserPasswordsJob)
      end

      it "returns to the school page" do
        post school_password_reset_path(school)
        expect(response).to redirect_to(school_path(school))
      end
    end

    context "as a teacher" do
      before do
        sign_in teacher
        post school_password_reset_path(school)
      end

      it "refuses the reset" do
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a student" do
      before do
        sign_in student
        post school_password_reset_path(school)
      end

      it "refuses the reset" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
