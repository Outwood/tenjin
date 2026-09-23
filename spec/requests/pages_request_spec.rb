# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages", :default_creates do
  describe "the home page" do
    context "when signed out" do
      before { get root_path }

      it "shows the landing page with the nav bar fixed to the top" do
        expect(Capybara.string(response.body)).to have_css("body[data-controller='pages'] nav.fixed-top")
      end
    end

    context "when signed in" do
      before do
        sign_in student
        get root_path
      end

      it "serves the dashboard" do
        expect(Capybara.string(response.body)).to have_css("body[data-controller='dashboards']")
      end
    end
  end

  describe "the about page" do
    before { allow(ENV).to receive(:[]).and_call_original }

    context "without the OGAT environment variable" do
      before do
        allow(ENV).to receive(:[]).with("OGAT").and_return(nil)
        get page_path("about")
      end

      it "shows the standard about page" do
        expect(Capybara.string(response.body)).to have_css("#standardAbout").and have_no_css("#ogatAbout")
      end

      it "does not fix the nav bar to the top" do
        expect(Capybara.string(response.body)).to have_no_css("nav.fixed-top")
      end
    end

    context "with the OGAT environment variable set" do
      before do
        allow(ENV).to receive(:[]).with("OGAT").and_return("true")
        get page_path("about")
      end

      it "shows the OGAT about page" do
        expect(Capybara.string(response.body)).to have_css("#ogatAbout").and have_no_css("#standardAbout")
      end
    end
  end
end
