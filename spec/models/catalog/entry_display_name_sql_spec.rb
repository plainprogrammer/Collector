require "rails_helper"

# Spec 066 decision 3: ordering by the name shown needs the same rule in SQL as `Catalog::Entry#display_name` has in Ruby.
RSpec.describe Catalog::Entry, type: :model do
  describe "DISPLAY_NAME_SQL" do
    it "evaluates to #display_name for English, localized, blank and whitespace-only localized printings", :aggregate_failures do
      entries = [
        create(:catalog_entry, name: "Lightning Bolt", language: "en", localized_name: "ignored"),
        create(:catalog_entry, name: "Lightning Bolt", language: "de", localized_name: "Blitzschlag"),
        create(:catalog_entry, name: "Lightning Bolt", language: "ja", localized_name: ""),
        create(:catalog_entry, name: "Lightning Bolt", language: "fr", localized_name: nil),
        create(:catalog_entry, name: "Lightning Bolt", language: "es", localized_name: "  ")
      ]

      shown = described_class.where(id: entries.map(&:id)).pluck(:id, described_class::DISPLAY_NAME_SQL).to_h

      entries.each { |entry| expect(shown.fetch(entry.id)).to eq(entry.display_name) }
    end
  end
end
