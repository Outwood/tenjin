# frozen_string_literal: true

# Ranks every customisation by how often pupils have bought it.
# Constructed cheaply; #customisations runs its query once and memoizes the rows.
class Customisation::PurchaseCounts
  def customisations
    @customisations ||= ranked.to_a
  end

  def top(limit)
    ranked.limit(limit)
  end

  private

  def ranked
    Customisation
      .select(:id, :name, :customisation_type, "COUNT(customisation_unlocks.id) AS times_bought")
      .left_joins(:customisation_unlocks)
      .group(:id)
      .order(times_bought: :desc, name: :asc)
  end
end
