# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Users", :default_creates, type: :request do
  let!(:author) { create(:teacher, school: school, forename: "Ada", surname: "Lovelace") }
  let!(:pupil) { create(:student, school: school, forename: "Grace", surname: "Hopper") }

  describe "GET /system/users" do
    before { sign_in super_admin }

    it "lists every user, linking each to their page" do
      get system_users_path
      expect(Capybara.string(response.body))
        .to have_link("Ada Lovelace", href: system_user_path(author))
        .and have_link("Grace Hopper", href: system_user_path(pupil))
    end

    it "filters by search term" do
      get system_users_path, params: {search: "lovel"}
      expect(Capybara.string(response.body))
        .to have_link("Ada Lovelace", href: system_user_path(author))
        .and have_no_link("Grace Hopper", href: system_user_path(pupil))
    end

    it "filters by held role" do
      author.add_role(:lesson_author, quiz_subject)
      get system_users_path, params: {role: "lesson_author"}
      expect(Capybara.string(response.body))
        .to have_link("Ada Lovelace", href: system_user_path(author))
        .and have_no_link("Grace Hopper", href: system_user_path(pupil))
    end

    it "filters by school" do
      elsewhere = create(:student, school: create(:school), forename: "Alan", surname: "Turing")
      get system_users_path, params: {school: elsewhere.school_id}
      expect(Capybara.string(response.body))
        .to have_link("Alan Turing", href: system_user_path(elsewhere))
        .and have_no_link("Ada Lovelace", href: system_user_path(author))
    end

    describe "with more users than fit on a page" do
      let!(:second_pupil) { create(:student, school: school, forename: "Alan", surname: "Turing") }

      before { stub_const("System::UsersController::PER_PAGE", 1) }

      it "shows one page at a time, linking to the rest" do
        get system_users_path

        expect(Capybara.string(response.body))
          .to have_link("Grace Hopper", href: system_user_path(pupil))
          .and have_no_link("Ada Lovelace", href: system_user_path(author))
          .and have_css("nav.pagy-bootstrap a", text: "2")
      end

      it "carries the filters into the page links" do
        get system_users_path, params: {type: "student"}

        expect(Capybara.string(response.body))
          .to have_link("Grace Hopper", href: system_user_path(pupil))
          .and have_no_link("Alan Turing", href: system_user_path(second_pupil))
          .and have_css("nav.pagy-bootstrap a[href*='type=student']")
      end

      it "lands on the first page rather than erroring before the start" do
        get system_users_path, params: {page: 0}

        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_link("Grace Hopper", href: system_user_path(pupil))
      end

      it "lands on the last page rather than erroring past the end" do
        get system_users_path, params: {page: 99}

        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_link("Alan Turing", href: system_user_path(second_pupil))
      end
    end

    describe "as a school group admin" do
      before { sign_in create(:school_group_admin) }

      it "lists the same users" do
        get system_users_path
        expect(Capybara.string(response.body))
          .to have_link("Ada Lovelace", href: system_user_path(author))
          .and have_link("Grace Hopper", href: system_user_path(pupil))
      end
    end
  end

  describe "GET /system/users/:id" do
    describe "as a super admin" do
      before do
        sign_in super_admin
        author.add_role(:lesson_author, quiz_subject)
        get system_user_path(author)
      end

      it "names the user and their school" do
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Ada Lovelace")
          .and have_content(school.name)
      end

      it "lists the roles they hold with the subject each is granted on" do
        expect(Capybara.string(response.body))
          .to have_css("#roles-table", text: "Lesson author")
          .and have_css("#roles-table", text: quiz_subject.name)
      end

      it "offers the email and setup-email controls" do
        expect(Capybara.string(response.body))
          .to have_field("user[email]", with: author.email)
          .and have_button("Send Setup Email")
      end
    end

    describe "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_user_path(author)
      end

      it "shows the user without the email or role controls" do
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Ada Lovelace")
          .and have_no_field("user[email]")
          .and have_no_button("Send Setup Email")
      end

      it "still offers impersonation" do
        expect(Capybara.string(response.body)).to have_button("Become User")
      end
    end

    describe "for a student" do
      before do
        sign_in super_admin
        get system_user_path(pupil)
      end

      it "offers no role controls, since roles are granted to employees only" do
        expect(Capybara.string(response.body)).to have_no_select("user[role]")
      end
    end
  end

  describe "GET /system/users/manage_roles" do
    before { sign_in super_admin }

    it "renders the manage_roles view" do
      get manage_roles_system_users_path
      expect(response).to have_http_status(:ok)
    end

    context "with a school selected" do
      before { get manage_roles_system_users_path(school: school) }

      it "renders every id once" do
        ids = Capybara.string(response.body).all("[id]").map { |element| element[:id] }
        expect(ids.tally.select { |_id, count| count > 1 }).to be_empty
      end

      it "leaves the role unchosen, so no click grants one by default" do
        expect(Capybara.string(response.body))
          .to have_css("select[name='user[role]'][required] option:first-child[value='']", exact_text: "Choose role…")
          .and have_no_css("select[name='user[role]'] option[selected]")
      end
    end
  end
end
