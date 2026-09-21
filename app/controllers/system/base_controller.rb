# frozen_string_literal: true

module System
  class BaseController < ApplicationController
    include System::PolicyNamespace

    before_action :authenticate_admin!

    layout "system"
  end
end
