require "rails_helper"

# Spec 042 FR-3: the scanner sitting is core code. Its models, partials and helper never name a collectible type or a source;
# the scale comes to them from the scanner's controllers (the ScannerSitting concern) or from the printing's own vocabulary.
# The pattern is spec 026's (spec/number_entry_core_spec.rb) without its finish words, because the helper's comments quote
# copy such as "Foil".
RSpec.describe "The scanner sitting's code" do
  let(:files) do
    Rails.root.glob("{app/models/scanner/sitting{,_entry}.rb,app/views/scanners/_{sitting,sitting_entry,picker,summary}.html.erb," \
      "app/helpers/scanners_helper.rb}")
  end

  it "covers every file of the feature" do
    expect(files.size).to eq(7)
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|magic)\b/i) }
    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
