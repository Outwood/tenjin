# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Users", :default_creates, type: :request do
  let!(:author) do
    create(:teacher, school: school, forename: "Ada", surname: "Lovelace",
      email: "ada@example.com", oauth_email: "ada.lovelace@gmail.example")
  end
  let!(:pupil) { create(:student, :no_oauth, school: school, forename: "Grace", surname: "Hopper") }

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

      it "names the user and links to their school" do
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Ada Lovelace")
          .and have_link(school.name, href: system_school_path(school))
      end

      it "shows the email and the linked Google account" do
        expect(Capybara.string(response.body))
          .to have_css("#email", exact_text: "ada@example.com")
          .and have_css("#google-account", exact_text: "ada.lovelace@gmail.example")
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

      it "shows the user's email without the controls to change it or their roles" do
        expect(Capybara.string(response.body))
          .to have_css("h1", text: "Ada Lovelace")
          .and have_css("#email", exact_text: "ada@example.com")
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

      it "shows no email and no Google account" do
        expect(Capybara.string(response.body))
          .to have_css("#email", exact_text: "—")
          .and have_css("#google-account", exact_text: "Not linked")
      end

      it "shows no classrooms" do
        expect(Capybara.string(response.body)).to have_content("No classrooms")
      end
    end

    context "with a user who signs in" do
      let!(:pupil) do
        create(:student, school: school, forename: "Grace", surname: "Hopper",
          sign_in_count: 3, current_sign_in_at: 2.days.ago)
      end

      before do
        sign_in super_admin
        get system_user_path(pupil)
      end

      it "shows them as active, with their last sign-in and how many they have made" do
        expect(Capybara.string(response.body))
          .to have_css("#status", exact_text: "Active")
          .and have_css("#last-sign-in", text: "2 days ago")
          .and have_css("#sign-in-count", exact_text: "3")
      end
    end

    context "with a disabled user who has never signed in" do
      let!(:pupil) { create(:student, school: school, forename: "Grace", surname: "Hopper", disabled: true) }

      before do
        sign_in super_admin
        get system_user_path(pupil)
      end

      it "shows them as inactive, with no sign-in" do
        expect(Capybara.string(response.body))
          .to have_css("#status", exact_text: "Inactive")
          .and have_css("#last-sign-in", exact_text: "Never")
      end

      it "offers no impersonation, which their sign-in would refuse" do
        expect(Capybara.string(response.body)).to have_no_button("Become User")
      end
    end

    context "with a user enrolled in a classroom" do
      let(:maths_class) { create(:classroom, school: school, subject: quiz_subject, name: "10x/Ma1") }
      let!(:enrolment) { create(:enrollment, user: pupil, classroom: maths_class) }

      before do
        sign_in super_admin
        get system_user_path(pupil)
      end

      it "lists the classroom with its subject" do
        expect(Capybara.string(response.body))
          .to have_css("#classrooms-table", text: "10x/Ma1")
          .and have_css("#classrooms-table", text: quiz_subject.name)
      end
    end
  end
end
