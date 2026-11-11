require "rails_helper"

# Spec 068 Story 7: how a file's proxies are read, judged and planned against the collector's own. The file is the account's
# own export, changed, so every deck and lot matches and only the proxies differ.
RSpec.describe CollectionImport, "#proxies", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing).entry }
  let!(:held) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2) }

  def file = CollectionExport.new(account:, at: Time.utc(2026, 11, 11)).to_h
  def read(data) = described_class.new(account:, file: StringIO.new(JSON.generate(data)))
  def entry_hash(entry) = { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language }
  def proxy(**changes) = file["proxies"].first.merge(changes.transform_keys(&:to_s))
  def with(proxies) = file.merge("proxies" => proxies)

  describe "the outcomes (decision 16)" do
    it "reads the account's own export as nothing to change", :aggregate_failures do
      import = read(file)

      expect(import.applicable?).to be(true)
      expect(import.plan.proxies.counted?).to be(true)
      expect(import.plan.proxies.counts).to eq(added: 0, changed: 0, unchanged: 1, removed: 0)
      expect(import.plan.nothing_to_change?).to be(true)
    end

    it "adds a row no held proxy has, changes one with another quantity, keeps an equal one and removes a held one the file lacks", :aggregate_failures do
      other = create(:mtg_printing).entry
      data = with([ proxy("quantity" => 5), proxy("entry" => entry_hash(other), "finish" => "nonfoil", "quantity" => 1) ])

      proxies = read(data).plan.proxies

      expect(proxies.counts).to eq(added: 1, changed: 1, unchanged: 0, removed: 0)
      expect(proxies.added.map(&:number)).to eq([ 2 ])
      expect(proxies.changed.map(&:number)).to eq([ 1 ])
      expect(proxies.held_for(proxies.changed.first).id).to eq(held.id)
      expect(read(with([])).plan.proxies.removed.map(&:id)).to eq([ held.id ])
    end

    it "counts the proxies of a deck or zone the file drops among the removed (decision 16)", :aggregate_failures do
      data = file.merge("decks" => [], "lots" => [], "proxies" => [])

      import = read(data)

      expect(import.plan.proxies.removed.map(&:id)).to eq([ held.id ])
      expect(import.plan.removes?).to be(true)
    end

    it "counts a held proxy that only a problem row names as removed (the preview can't be applied then)", :aggregate_failures do
      data = with([ proxy("quantity" => 0) ])

      import = read(data)

      expect(import.applicable?).to be(false)
      expect(import.plan.proxies.removed.map(&:id)).to eq([ held.id ])
    end

    it "lists the removed proxies by deck, zone, name, set, number, language and finish (decision 16)" do
      second = create(:deck_proxy, zone: deck.zone("considering"), account:, entry: create(:mtg_printing).entry)

      expect(read(with([])).plan.proxies.removed.map(&:id)).to eq([ second.id, held.id ]) # the zone key "considering" sorts before "main"
    end

    it "judges nothing for a file older than version 4, and leaves the proxies (decision 15)", :aggregate_failures do
      v3 = file.except("proxies", "decks").merge("format_version" => 3)
      v3["lots"] = []

      proxies = read(v3).plan.proxies

      expect(proxies.counted?).to be(false)
      expect([ proxies.removes?, proxies.nothing_to_change?, proxies.removed ]).to eq([ false, true, [] ])
    end
  end

  describe "the whole file's refusals (decision 14, AC-7.5)" do
    it "refuses a version 4 file with no proxies list, naming it", :aggregate_failures do
      import = read(file.except("proxies"))

      expect(import.refused?).to be(true)
      expect([ import.refusal.rule, import.refusal.at ]).to eq([ "required", "/proxies" ])
      expect(import.refusal.reason).to include("proxies")
    end

    it "refuses a proxies value that isn't a list", :aggregate_failures do
      import = read(file.merge("proxies" => {}))

      expect([ import.refused?, import.refusal.at ]).to eq([ true, "/proxies" ])
    end
  end

  describe "the problem rows (decision 18, AC-7.6)" do
    def reasons(data) = read(data).proxy_problem_rows.flat_map { |row| row.problems.map { [ row.number, it.rule, it.reason ] } }

    it "is a row problem, not a refusal, for a field that fails the schema", :aggregate_failures do
      import = read(with([ proxy("quantity" => 0) ]))

      expect(import.refused?).to be(false)
      expect(import.proxy_problem_rows.map(&:number)).to eq([ 1 ])
      expect(import.proxy_problem_rows.first.problems.map(&:rule)).to eq([ "minimum" ])
      expect(import.applicable?).to be(false)
    end

    it "names each reader's rule with its reason", :aggregate_failures do
      other = create(:mtg_printing).entry
      expect(reasons(with([ proxy("deck" => "Nope") ]))).to eq([ [ 1, "unknown_location", "Its deck “Nope” isn't one of the file's decks." ] ])
      expect(reasons(with([ proxy("zone" => "no-such-zone") ]))).to eq([ [ 1, "unknown_zone", "The deck “Izzet Tempo” has no zone “no-such-zone” in its format." ] ])
      expect(reasons(with([ proxy("entry" => entry_hash(other).merge("collectible_type" => "gone")) ]))).to eq([ [ 1, "unknown_type", "This instance doesn't collect gone" ] ])
      expect(reasons(with([ proxy("entry" => entry_hash(other).merge("source_id" => "nope")) ]))).to eq([ [ 1, "not_in_catalog", "Not in this instance's catalog" ] ])
      expect(reasons(with([ proxy("finish" => "etched") ]))).to eq([ [ 1, "finish_not_listed", "This printing doesn't come in etched" ] ])
      expect(reasons(with([ proxy, proxy ]))).to eq([ [ 2, "duplicate_proxy", "Same deck, zone, card and finish as proxy 1" ] ])
    end

    it "accepts a proxy with no finish, for a printing that lists finishes too (decision 2)" do
      expect(read(with([ proxy("finish" => nil) ])).proxy_problem_rows).to be_empty
    end

    it "never compares a proxy's collectible type with its deck's (decision 19)" do
      other_type = create(:catalog_entry, collectible_type: "other") # a type the instance has no source for
      problems = read(with([ proxy("entry" => entry_hash(other_type), "finish" => nil) ])).proxy_problem_rows.flat_map { |row| row.problems.map(&:rule) }

      expect(problems).to eq([ "unknown_type" ]) # the type isn't registered here; a registered one is never compared with the deck's
    end

    it "counts the problems of every row by their summary, and lists the first LIST_LIMIT rows", :aggregate_failures do
      rows = Array.new(3) { proxy("quantity" => 0) }.each_with_index.map { |row, index| row.merge("zone" => "z#{index}") }

      import = read(with(rows))

      expect(import.proxy_problem_counts).to eq("quantity isn't valid" => 3)
      expect(import.listed_proxy_problem_rows.size).to eq(3)
    end
  end
end
