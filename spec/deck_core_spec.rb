require "rails_helper"
require "tempfile"

# Spec 062 AC-9.11 (decision 2): the deck code is core code. Its controllers, views, models, helper, icon and the import's deck
# files never name a collectible, a source, a deck format or a zone: the formats and their zones come from a collectible's
# registration through `Catalog::Formats`, and the one zone key the core may name is `considering`. A name is matched anywhere
# in a word, comments included (issue #209: `_` is a word character, so `scryfall_id` and `MTGPrinting` would slip past `\b`).
# The format and zone keys are ordinary English words (a "standard" action, a "modern" browser), so they are matched as words
# of their own, not between letters, but `modern_format` counts. `main` is a common word in views and is reviewed by eye.
# Known limit: a CamelCase compound (`ModernDeck`) passes.
RSpec.describe "The deck code", type: :config do
  let(:game_names) { /mtg|scryfall|magic/i }
  let(:format_and_zone_keys) { /(?<![a-z])(casual|standard|pioneer|modern|legacy|vintage|pauper|commander|sideboard)(?![a-z])/i }

  # The deck files the guard covers, by glob.
  let(:patterns) do
    %w[
    app/controllers/decks_controller.rb app/controllers/decks/*.rb app/views/decks/**/*.erb
    app/models/deck.rb app/models/deck/*.rb app/models/location/placement.rb app/models/catalog/formats.rb
    app/helpers/decks_helper.rb app/models/collection_import/decks.rb app/models/collection_import/deck_changes.rb
    app/views/collections/import_previews/_decks.html.erb app/views/icons/_decks.html.erb
    app/models/location/choices.rb app/helpers/location_choices_helper.rb
    app/views/lots/_form.html.erb app/views/lots/moves/new.html.erb
    app/views/collections/_location_select.html.erb app/views/collections/moves/new.html.erb
  ]
  end

  let(:files) { patterns.flat_map { |pattern| Rails.root.glob(pattern) }.uniq }

  def naming?(text) = text.match?(game_names) || text.match?(format_and_zone_keys)

  def relative(files) = files.map { |file| file.relative_path_from(Rails.root).to_s }

  it "covers every file of the feature" do
    expect(files.size).to eq(20 + 6 + 1) # spec 064 brought the list to 20; spec 065 adds the choices model, its helper and the four picker views; spec 066 adds Deck::Page (the `app/models/deck/*.rb` glob already covers it)
  end

  it "names every file it lists, each of which exists" do
    expect(patterns.reject { |pattern| Rails.root.glob(pattern).any? }).to be_empty
  end

  it "never names a game, a source, a deck format or a zone other than considering (comments included)" do
    expect(relative(files.select { |file| naming?(file.read) })).to be_empty
  end

  describe "the matcher" do
    def named_in(text)
      Tempfile.create([ "deck_core_guard", ".rb" ]) do |file|
        file.write(text)
        file.flush
        naming?(File.read(file.path))
      end
    end

    it "fails on an identifier-shaped name of a game, a source or a format, in code or a comment", :aggregate_failures do
      [ "scryfall_id", "MTGPrinting", "# a Magic card", "format = 'modern'", "modern_format", "zones: %w[main sideboard]", "key == :commander",
        "# the Standard format" ].each do |text|
        expect(named_in(text)).to be(true), "#{text.inspect} passed the guard"
      end
    end

    it "passes the one zone key core code names and the words around it", :aggregate_failures do
      [ "Catalog::Formats::CONSIDERING", "zone.key == 'considering'", "# the main view of a deck", "format.key", "formatter" ].each do |text|
        expect(named_in(text)).to be(false), "#{text.inspect} failed the guard"
      end
    end
  end
end
