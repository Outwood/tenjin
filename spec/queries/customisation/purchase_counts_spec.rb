# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customisation::PurchaseCounts do
  subject(:counts) { described_class.new }

  let!(:popular) { create(:customisation, name: "Midnight Theme") }
  let!(:unbought) { create(:customisation, name: "Sunrise Theme") }

  before { create_list(:customisation_unlock, 2, customisation: popular) }

  it "counts how often each customisation was bought" do
    expect(counts.customisations.map { |c| [c.name, c.times_bought] })
      .to eq([["Midnight Theme", 2], ["Sunrise Theme", 0]])
  end

  describe "#top" do
    it "keeps only the most bought" do
      expect(counts.top(1).map(&:name)).to eq(["Midnight Theme"])
    end
  end
end
