# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Schools", :default_creates, type: :request do
  let(:school_group_admin) { create(:school_group_admin) }
  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }

  # Capybara.string drops a <template>'s content, so read the stream's markup directly
  def stream_update(target)
    template = Nokogiri::HTML4(response.body).at_css("turbo-stream[action='update'][target='#{target}'] template")
    Capybara.string(template&.inner_html.to_s)
  end

  describe "GET /system/schools" do
    let!(:school) { super() }

    before do
      sign_in admin
      get system_schools_path
    end

    context "as a super admin" do
      let(:admin) { super_admin }

      it "offers a sync" do
        expect(Capybara.string(response.body)).to have_button("Sync")
      end

      it "holds the page, but not the navbar, in the main landmark" do
        expect(Capybara.string(response.body)).to have_css("main h1", exact_text: "Schools")
          .and have_no_css("main #navbar-main")
      end

      it "shows no breadcrumb on a top-level page" do
        expect(Capybara.string(response.body)).to have_no_css("nav[aria-label='Breadcrumb']")
      end

      it "labels the account menu with the admin's initial and offers Sign out" do
        expect(Capybara.string(response.body).find("#account-menu"))
          .to have_button(exact_text: admin.email.first.upcase, visible: :all)
          .and have_css("button[aria-label='Account menu for #{admin.email}']")
          .and have_button("Sign out", visible: :all)
      end

      it "colours the avatar for the signed-in admin" do
        colour = "admin-avatar-#{admin.id % AdminAreaHelper::AVATAR_COLOURS}"

        expect(Capybara.string(response.body))
          .to have_css("#account-menu button.admin-avatar.#{colour}", visible: :all)
      end

      it "reaches the email, the Settings pages and Sign out where the collapsed menu would hide the avatar" do
        expect(Capybara.string(response.body).find("#account-links"))
          .to have_text(admin.email)
          .and have_link("Admins", href: system_admins_path)
          .and have_link("Maintenance", href: system_maintenance_path)
          .and have_button("Sign out")
      end

      it "collapses the navbar and swaps the account and settings menus below the medium breakpoint" do
        expect(Capybara.string(response.body))
          .to have_css("#navbar-main.navbar-expand-md #account-links.d-md-none")
          .and have_css("#navbar-main.navbar-expand-md .d-md-flex > #account-menu")
          .and have_css("#navbar-main.navbar-expand-md #settings-menu.d-none.d-md-block")
      end
    end

    context "as a school group admin" do
      let(:admin) { school_group_admin }

      it "offers no sync, which only super admins may run" do
        expect(Capybara.string(response.body)).to have_no_button("Sync")
      end

      it "keeps the Settings pages out of the collapsed menu, which only super admins may open" do
        expect(Capybara.string(response.body).find("#account-links"))
          .to have_no_link("Admins")
          .and have_no_link("Maintenance")
          .and have_button("Sign out")
      end

      it "collapses at the same breakpoint as a super admin, who has more links" do
        expect(Capybara.string(response.body))
          .to have_css("#navbar-main.navbar-expand-md #account-links.d-md-none")
          .and have_css("#navbar-main.navbar-expand-md .d-md-flex > #account-menu")
      end
    end
  end

  describe "POST /system/schools" do
    let(:school_url) { "https://api.wonde.com/v1.0/schools/A000000000" }

    before { sign_in super_admin }

    context "when Wonde does not recognise the id" do
      before do
        stub_request(:get, school_url).to_return(status: 404, body: {error: "not_found"}.to_json)
        post system_schools_path, params: {school: {client_id: "A000000000", token: "a-token"}}
      end

      it "re-renders the form with the reason against the id" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(Capybara.string(response.body))
          .to have_css(".invalid-feedback", text: "Client ID is not a school this token can read on Wonde")
          .and have_field("Client ID", with: "A000000000")
      end

      it "adds no school" do
        expect(School.where(client_id: "A000000000")).not_to exist
      end
    end

    context "when Wonde does not answer" do
      before do
        stub_request(:get, school_url).to_timeout
        post system_schools_path, params: {school: {client_id: "A000000000", token: "a-token"}}
      end

      it "re-renders the form with the failure above it" do
        expect(Capybara.string(response.body))
          .to have_css(".alert-danger", text: "Wonde could not supply this school. Check the Client ID and token, or try again later.")
      end
    end
  end

  describe "PATCH /system/schools/:id" do
    before { sign_in super_admin }

    it "redraws the permitted toggle in its new state" do
      patch system_school_path(school), params: {school: {permitted: false}}, headers: turbo_headers
      expect(stream_update("permitted_school_#{school.id}")).to have_field("Permitted", type: "checkbox", checked: false)
    end
  end

  describe "GET /system/schools/:id" do
    before do
      sign_in admin
      get system_school_path(school)
    end

    context "as a super admin" do
      let(:admin) { super_admin }

      it "links to the school's staff page" do
        expect(response.body).to include(system_school_staff_index_path(school))
      end

      context "with pupils and staff on the roll" do
        let!(:pupils) { create_list(:student, 2, school: school) }
        let!(:staff) { create(:teacher, school: school) }

        # The outer GET ran before these records existed
        before { get system_school_path(school) }

        it "counts each role" do
          expect(Capybara.string(response.body)).to have_xpath("//tr[td='Students'][td='2']")
            .and have_xpath("//tr[td='Employees'][td='1']")
        end
      end

      context "with a leaver on the roll" do
        let!(:pupil) { create(:student, school: school) }
        let!(:leaver) { create(:student, school: school, disabled: true) }

        # The outer GET ran before these records existed
        before { get system_school_path(school) }

        it "offers impersonation of the current pupil but not the leaver" do
          expect(Capybara.string(response.body))
            .to have_css("tr#user-#{pupil.id} button", exact_text: "Become User")
            .and have_no_css("tr#user-#{leaver.id} button")
        end
      end

      it "titles the tab after the school and leads back to Schools" do
        expect(Capybara.string(response.body)).to have_title("#{school.name} · Tenjin admin")
          .and have_css("nav[aria-label='Breadcrumb'] a[href='#{system_schools_path}']", exact_text: "Schools")
          .and have_css(".breadcrumb-item.active[aria-current='page']", exact_text: school.name)
      end
    end

    context "as a school group admin" do
      let(:admin) { school_group_admin }

      it "does not link to the staff page" do
        expect(response.body).not_to include(system_school_staff_index_path(school))
      end
    end
  end
end
