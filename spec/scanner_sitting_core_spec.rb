require "rails_helper"

# Spec 042 FR-3, spec 088 FR-1: the scanner sitting and the selection pane are core code. Their models, partials and helper never name a collectible type or a source;
# the scale comes to them from the scanner's controllers (the ScannerSitting concern) or from the printing's own vocabulary.
# The pattern is spec 026's (spec/number_entry_core_spec.rb) without its finish words, because the helper's comments quote
# copy such as "Foil". Issue #209: the names are matched anywhere in a word (scryfall_id, MTGPrinting), because `_` is a
# word character and `\b` would let them through.
RSpec.describe "The scanner sitting's code" do
  let(:files) do
    Rails.root.glob("{app/models/scanner/sitting{,_entry}.rb,app/views/scanners/_{sitting,sitting_entry,picker,sitting_bar,count,added_line,added_action,destination_sheet,list_sheet}.html.erb," \
      "app/helpers/scanners_helper.rb,app/models/scanner/selection.rb," \
      "app/views/scanners/_{selection,item,more_item,panel,more_panel,band_content,add_buttons}.html.erb}")
  end

  it "covers every file of the feature" do
    expect(files.size).to eq(20)
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.read.match?(/mtg|scryfall|magic/i) }
    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
