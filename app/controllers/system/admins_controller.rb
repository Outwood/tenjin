# frozen_string_literal: true

module System
  class AdminsController < BaseController
    def show
      authorize current_admin
    end
  end
end
