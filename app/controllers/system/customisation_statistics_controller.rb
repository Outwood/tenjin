# frozen_string_literal: true

module System
  # How often each customisation has been bought, across the platform.
  class CustomisationStatisticsController < BaseController
    def show
      authorize :customisation_statistics

      @customisations = Customisation::PurchaseCounts.new.customisations
    end
  end
end
