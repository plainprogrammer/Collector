require "rails_helper"

# Spec 033 FR-6, spec 048 AC-2.4: the place line and the Location column are core code. The files spec 033 changed
# (git diff --name-only a3baf0d^1 a3baf0d, less the stylesheet and the specs) name no collectible type or source.
# Finish names are not checked: a comment in lots_helper.rb names one.
RSpec.describe "The place line's core code", type: :config do
  let(:files) do
    %w[
      app/models/collection_grid.rb app/models/collection_table.rb app/models/collection_filter.rb
      app/helpers/lots_helper.rb app/views/collections/_tile.html.erb app/views/collections/_table.html.erb
      app/views/collections/_lot_cells.html.erb
    ]
  end

  it "exists, every file of it" do
    expect(files.reject { |file| Rails.root.join(file).exist? }).to be_empty
  end

  it "never names a collectible type or a source" do
    named = files.select { |file| Rails.root.join(file).exist? && Rails.root.join(file).read.match?(/\b(mtg|scryfall|magic)\b/i) }

    expect(named).to be_empty
  end
end
