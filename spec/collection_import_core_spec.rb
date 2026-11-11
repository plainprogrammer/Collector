require "rails_helper"

# Spec 025 FR-9: the import preview's reader, controller, views and helper name no collectible type or source.
# Issue #209: the names are matched anywhere in a word (scryfall_id, MTGPrinting), because `_` is a word character and
# `\b` would let them through.
# Spec 062 AC-9.11: nor a game's name, a deck format's key or a zone's key (`casual standard pioneer modern legacy vintage pauper
# commander sideboard`, matched as words of their own: `modern_format` counts, `modernise` doesn't).
RSpec.describe "The import preview's code" do
  let(:files) do
    %w[app/models/collection_import.rb app/models/collection_import/decks.rb app/models/collection_import/proxies.rb
       app/models/collection_import/proxy_rows.rb app/views/collections/import_previews/_proxies.html.erb app/models/export_format/rules.rb app/controllers/collections/import_previews_controller.rb
       app/views/collections/import_previews/new.html.erb app/views/collections/import_previews/show.html.erb
       app/helpers/import_previews_helper.rb].map { |path| Rails.root.join(path) }
  end

  it "exists, every file of it" do
    expect(files.reject(&:exist?)).to be_empty
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.exist? && file.read.match?(/mtg|scryfall|magic|(?<![a-z])(casual|standard|pioneer|modern|legacy|vintage|pauper|commander|sideboard)(?![a-z])/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
