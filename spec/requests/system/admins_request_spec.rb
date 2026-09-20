# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System::Admins", :default_creates, type: :request do
  before { sign_in super_admin }

  describe "GET /system/admins/:id" do
    it "renders the admin show page" do
      get system_admin_path(super_admin)
      expect(response).to have_http_status(:ok)
    end
  end
end
