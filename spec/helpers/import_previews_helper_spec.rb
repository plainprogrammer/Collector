require "rails_helper"

# Spec 038 decision 8: the preview writes each price in the currency its caller names.
RSpec.describe ImportPreviewsHelper, type: :helper do
  describe "#import_lot_line" do
    def line(price_paid, currency) = helper.import_lot_line(set_code: "dmr", collector_number: "27", language: "en", finish: "foil", condition: nil, price_paid:, currency:)

    it "writes a price in the format's form with the given currency's symbol (AC-6.8)", :aggregate_failures do
      expect(line("12.50", Collector::Currency.fetch!("EUR"))).to eq("DMR · 27 · EN · Foil · €12.50")
      expect(line("12.50", Collector::Currency.fetch!("GBP"))).to end_with("£12.50")
    end

    it "writes a price in another form as the file gives it" do
      expect(line("12,5", Collector::Currency.fetch!("EUR"))).to end_with("· 12,5")
    end
  end
end
