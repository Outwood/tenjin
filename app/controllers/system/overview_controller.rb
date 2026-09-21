# frozen_string_literal: true

module System
  # The admin area's landing page: how the platform as a whole is doing.
  class OverviewController < BaseController
    def show
      authorize :overview

      @school_statistics = School::Statistics.new
      @customisations = Customisation::PurchaseCounts.new.top(5)
    end
  end
end
