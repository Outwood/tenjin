# frozen_string_literal: true

module System
  # The admin area's landing page: how the platform as a whole is doing.
  class OverviewController < BaseController
    def show
      authorize :overview

      @school_statistics = School::Statistics.new
      @customisation_statistics = Customisation
        .select(:id, :name, :customisation_type, "COUNT(customisation_unlocks.id) AS times_bought")
        .left_joins(:customisation_unlocks)
        .group(:id)
        .order(times_bought: :desc, name: :asc)
        .limit(5)
    end
  end
end
