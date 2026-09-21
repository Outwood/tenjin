# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::SchoolGroups", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/school_groups" do
    it "links each group by name to its edit form" do
      school_group = create(:school_group, name: "North")
      get system_school_groups_path
      expect(Capybara.string(response.body)).to have_link("North", href: edit_system_school_group_path(school_group))
    end

    it "says when there are none" do
      get system_school_groups_path
      expect(Capybara.string(response.body)).to have_text("No school groups yet.")
    end

    describe "as a school group admin" do
      before do
        sign_in create(:school_group_admin)
        get system_school_groups_path
      end

      it "refuses" do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "GET /system/school_groups/:id/edit" do
    it "renders the edit form" do
      school_group = create(:school_group, name: "South")
      get edit_system_school_group_path(school_group)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("South")
    end
  end

  describe "POST /system/school_groups" do
    it "creates a school group" do
      expect {
        post system_school_groups_path, params: {school_group: {name: "East"}}
      }.to change(SchoolGroup, :count).by(1)
      expect(response).to redirect_to(system_school_groups_path)
    end

    it "does not create a school group with a blank name" do
      expect {
        post system_school_groups_path, params: {school_group: {name: ""}}
      }.not_to change(SchoolGroup, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /system/school_groups/:id" do
    it "does not save a blank name" do
      school_group = create(:school_group, name: "West")
      patch system_school_group_path(school_group), params: {school_group: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
      expect(school_group.reload.name).to eq("West")
    end
  end

  describe "DELETE /system/school_groups/:id" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html, text/html"} }
    let!(:school_group) { create(:school_group) }

    context "with no schools" do
      it "deletes the group" do
        expect {
          delete system_school_group_path(school_group), headers: turbo_headers
        }.to change(SchoolGroup, :count).by(-1)
        expect(response).to redirect_to(system_school_groups_path)
      end
    end

    context "with a school in the group" do
      before { create(:school, school_group: school_group) }

      it "keeps the group and explains why" do
        expect {
          delete system_school_group_path(school_group), headers: turbo_headers
        }.not_to change(SchoolGroup, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("still has schools")
      end
    end
  end
end
