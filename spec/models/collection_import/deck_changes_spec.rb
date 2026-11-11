require "rails_helper"

# Spec 062 AC-8.1, AC-8.3, AC-8.9: what an apply writes of the collector's decks, places and zones, in what order and in how
# many statements. The apply's own examples (apply_spec.rb) judge the result from a stored upload; these judge the writes.
RSpec.describe CollectionImport::DeckChanges, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def import(decks: [], locations: [], lots: [], version: 4)
    data = version == 4 ? import_file_v4(user, lots, decks:, locations:) : import_file_v3(user, lots, locations:)
    CollectionImport.new(account:, file: import_io(data))
  end

  def write!(parsed) = described_class.write!(account, parsed.locations, parsed.decks)

  # The write statements to these tables, as SQL.
  def statements(*tables)
    found = []
    counter = ->(*, payload) { found << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b.*"(#{tables.join("|")})"/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    found
  end

  describe ".write!" do
    it "upserts the places and the decks on the top-level name index, with its condition, so an index that is partial is the conflict target", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:deck, account:, name: "elves")
      parsed = import(locations: [ "Box", "Crate" ], decks: [ "Elves", "New" ])

      written = statements("locations") { write!(parsed) }

      upserts = written.grep(/DO UPDATE/)
      expect(upserts.size).to eq(2) # the places', then the decks'
      expect(upserts).to all(include('ON CONFLICT ("account_id","name_key") WHERE parent_id IS NULL DO UPDATE SET'))
      expect(account.locations.top_level.order(:name_key).pluck(:kind, :name)).to eq([ %w[place Box], %w[place Crate], %w[deck Elves], %w[deck New] ].sort_by { |_kind, name| name.downcase })
    end

    it "inserts a zone with the conflict target of the zone name index, which skips a duplicate", :aggregate_failures do
      deck = create(:deck, account:, name: "Izzet Tempo")
      deck.zone("considering").destroy!

      written = statements("locations") { write!(import(decks: [ "Izzet Tempo" ])) }

      expect(written.grep(/INSERT/).sole).to include('ON CONFLICT ("parent_id","name_key") WHERE parent_id IS NOT NULL DO NOTHING')
      expect(deck.zones.pluck(:zone)).to eq(%w[main sideboard considering])
    end

    it "touches no deck, no zone and no deck row for a plan that says nothing of decks, and still writes its places", :aggregate_failures do
      deck = create(:deck, account:, name: "Izzet Tempo")
      zones = deck.zones.pluck(:id, :name, :updated_at)

      written = statements("decks", "locations") { write!(import(version: 3, locations: [ "Box" ])) }

      expect(written.grep(/"decks"/)).to be_empty
      expect(deck.zones.pluck(:id, :name, :updated_at)).to eq(zones)
      expect(account.locations.places.pluck(:name)).to eq([ "Box" ])
      expect(account.locations.decks.pluck(:name)).to eq([ "Izzet Tempo" ])
    end

    it "writes nothing for a plan with nothing to change", :aggregate_failures do
      deck = create(:deck, account:, name: "Izzet Tempo")
      create(:location, account:, name: "Box")

      written = statements("decks", "locations") { write!(import(locations: [ "Box" ], decks: [ "Izzet Tempo" ])) }

      expect(written).to be_empty
      expect(deck.reload.zones.count).to eq(3)
    end

    it "writes rows the models accept, whatever the kind", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:deck, account:, name: "elves", format: "commander")
      write!(import(locations: [ "Box", "Straße" ], decks: [ "Elves", { "name" => "Café", "collectible_type" => "mtg", "format" => "pauper" } ]))

      expect(account.locations.includes(:parent)).to all(be_valid)
      expect(account.decks).to all(be_valid)
      expect(account.decks.joins(:location).order("locations.name_key").pluck("locations.name", :format)).to eq([ %w[Café pauper], %w[Elves modern] ].sort_by { |name, _| name.downcase })
    end

    it "runs the same number of write statements for 2 decks as for 40", :aggregate_failures do
      count = lambda do |decks|
        other = create(:user)
        Array.new(decks) { |n| create(:deck, account: other.account, name: "held #{n}") }
        file = Array.new(decks / 2) { |n| { "name" => "HELD #{n}", "collectible_type" => "mtg", "format" => "commander" } } + Array.new(decks / 2) { |n| "New #{n}" }
        parsed = CollectionImport.new(account: other.account, file: import_io(import_file_v4(other, [], decks: file)))
        write_statements = []
        counter = ->(*, payload) { write_statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.write!(other.account, parsed.locations, parsed.decks) }
        [ write_statements.size, other.account.decks.count ]
      end

      small = count.call(2)
      large = count.call(40)

      expect(large.first).to eq(small.first)
      expect([ small.last, large.last ]).to eq([ 2, 40 ])
    end
  end
end
