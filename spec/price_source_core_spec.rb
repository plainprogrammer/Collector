require "rails_helper"

# Spec 085 decision 12, AC-4.1: the core of prices names no collectible, source or marketplace, comments included.
# Substring matching, not a word, so scryfall_id and MTGPrinting are caught too (issue #209).
RSpec.describe "the price source contract is core", type: :model do
  let(:matcher) { /mtg|magic|scryfall|tcgplayer|cardmarket/i }
  let(:core_files) do
    %w[app/models/prices.rb app/models/prices/**/*.rb app/models/price_source.rb app/models/price_series.rb app/models/current_price.rb app/models/price_change.rb app/models/price_refresh_run.rb app/jobs/prices/**/*.rb]
      .flat_map { |pattern| Rails.root.glob(pattern) }
  end

  it "names no collectible, source or marketplace in the files it adds", :aggregate_failures do
    expect(core_files).not_to be_empty
    expect(core_files.select { |file| file.read.match?(matcher) }.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end

  it "has a matcher that flags a name, so the guard can fail" do
    samples = [ "a Scryfall file", "Magic cards", "an MTG type", "TCGplayer", "Cardmarket", "scryfall_id", "MTGPrinting" ]

    expect(samples.reject { |text| text.match?(matcher) }).to be_empty
  end
end
