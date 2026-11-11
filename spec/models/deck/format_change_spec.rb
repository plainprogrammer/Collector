require "rails_helper"

# Spec 064 Stories 1 and 2: changing a deck's format makes its zones the new format's and moves the lots of dropped zones
# into Considering, all or nothing.
RSpec.describe Deck::FormatChange, type: :model do
  let(:account) { create(:user).account }

  def change_to(deck, key) = described_class.new(deck:, format: "mtg/#{key}") # not `change`: that is RSpec's matcher
  def zone_keys(deck) = deck.zones.pluck(:zone)
  def written = [ Location.count, Deck.count, Lot.count ]

  # A vocabulary registered as the type "fake" with two formats: "f" has the zones a, b and considering, "g" only considering,
  # so one change drops two zones (no shipped format does).
  def fake_vocabulary
    zone = ->(key, name) { Catalog::Formats::Zone.new(key:, name:) }
    formats = [ Catalog::Formats::Format.new(key: "f", name: "F", default: true, zones: [ zone.("a", "A"), zone.("b", "B"), zone.("considering", "Considering") ]),
                Catalog::Formats::Format.new(key: "g", name: "G", default: false, zones: [ zone.("considering", "Considering") ]) ]
    # The bulk move orders its lots by every registered type's finish order and condition scale, so the fake answers both.
    stub_const("FakeDeckVocabulary", Module.new do
      define_singleton_method(:formats) { formats }
      define_singleton_method(:finish_order) { [] }
      define_singleton_method(:conditions) { {} }
      define_singleton_method(:finishes_for) { |_entry| [] }
      define_singleton_method(:finish_label) { |finish| finish.to_s }
    end)
    Catalog.collecting["fake"] = "FakeDeckVocabulary"
  end

  after { Catalog.collecting.delete("fake") }

  describe "#save" do
    it "changes the type and format and nothing else when the formats share their zones (AC-1.3, AC-1.4)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      lot = create_lot_in_zone(deck, "main", quantity: 3)
      create_lot_in_zone(deck, "sideboard", quantity: 2)
      location_id = deck.location_id
      zones = -> { deck.zones.order(:id).pluck(:id, :name, :name_key, :updated_at) }
      lots = -> { Lot.order(:id).pluck(:id, :lot_key, :quantity, :location_id, :updated_at) }
      before = [ zones.call, lots.call ]
      form = change_to(deck, "pauper")

      expect(form.save).to be(true)

      expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "pauper")
      expect(deck.location_id).to eq(location_id)
      expect([ zones.call, lots.call ]).to eq(before)
      expect(lot.reload.location_id).to eq(deck.zone("main").id)
      expect([ form.changed?, form.moved ]).to eq([ true, 0 ])
    end

    it "drops and adds zones from the deck's rows: Commander to Modern keeps Main and Considering and adds Sideboard (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      kept = deck.zones.where(zone: %w[main considering]).pluck(:zone, :id).to_h

      expect(change_to(deck, "modern").save).to be(true)

      expect(zone_keys(deck)).to contain_exactly("main", "considering", "sideboard")
      expect(deck.zones.where(zone: %w[main considering]).pluck(:zone, :id).to_h).to eq(kept)
      expect(deck.zone("sideboard")).to have_attributes(name: "Sideboard", kind: "deck_zone", parent_id: deck.location_id, account_id: account.id)
    end

    it "goes back the other way: Modern to Commander drops Sideboard and adds Commander (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")

      expect(change_to(deck, "commander").save).to be(true)

      expect(zone_keys(deck)).to contain_exactly("main", "considering", "commander")
      expect(deck.zone("commander")).to have_attributes(name: "Commander")
    end

    it "rewrites a kept zone's name from the registration, so no unique-index error can happen (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      deck.zone("main").update_columns(name: "Sideboard", name_key: "sideboard") # a stale name another zone is about to take

      expect(change_to(deck, "modern").save).to be(true)

      expect(deck.zone("main")).to have_attributes(name: "Main", name_key: "main")
      expect(deck.zone("sideboard")).to have_attributes(name: "Sideboard", name_key: "sideboard")
    end

    it "does nothing for the format the deck already has, writing no row and moving no timestamp (AC-1.6)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      create_lot_in_zone(deck, "sideboard", quantity: 2)
      stamps = [ Deck.pluck(:updated_at), Location.pluck(:updated_at), Lot.pluck(:updated_at) ]
      form = change_to(deck, "modern")

      expect(form.save).to be(true)

      expect([ form.changed?, form.moved ]).to eq([ false, 0 ])
      expect([ Deck.pluck(:updated_at), Location.pluck(:updated_at), Lot.pluck(:updated_at) ]).to eq(stamps)
    end

    it "reads the format under the write lock: a stale deck object that already has the chosen format changes nothing (AC-1.6)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      stale = Deck.find(deck.id)
      change_to(deck, "pauper").save!

      form = change_to(stale, "pauper")

      expect { form.save }.not_to change { [ Location.count, Lot.count ] }
      expect(form.changed?).to be(false)
    end

    it "changes a deck whose format the instance no longer registers, judging by its zone rows (AC-1.7)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      create_lot_in_zone(deck, "commander", quantity: 2)
      deck.update!(format: "retired")

      form = change_to(deck, "modern")

      expect(form.save).to be(true)
      expect(form.moved).to eq(2)
      expect(deck.reload.format).to eq("modern")
    end

    it "changes a deck whose collectible type the instance no longer registers, and moves its dropped zone's lots (AC-1.7)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      lot = create_lot_in_zone(deck, "commander", quantity: 2)
      deck.update!(collectible_type: "gone")

      form = change_to(deck, "modern")

      expect(form.save).to be(true)
      expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "modern")
      expect(lot.reload.location_id).to eq(deck.zone("considering").id)
      expect([ form.moved, zone_keys(deck) ]).to eq([ 2, %w[main considering sideboard] ])
    end

    it "refuses a blank, unregistered or foreign-key format with 'Choose a format.' and writes nothing (AC-3.1)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")

      [ "", "modern", "nope/modern", "mtg/nope" ].each do |value|
        form = described_class.new(deck:, format: value)
        expect { expect(form.save).to be(false) }.not_to change { [ written, deck.reload.format ] }
        expect(form.errors[:format]).to eq([ "Choose a format." ])
      end
    end

    context "when zones are dropped" do
      let(:deck) { create(:deck, account:, format: "commander") }
      let(:considering) { deck.zone("considering") }

      it "moves every lot of a dropped zone into Considering, leaves the others where they are and says how many copies (AC-2.1)", :aggregate_failures do
        first = create_lot_in_zone(deck, "commander", quantity: 2)
        second = create_lot_in_zone(deck, "commander", quantity: 1)
        main = create_lot_in_zone(deck, "main", quantity: 4)
        there = create_lot_in_zone(deck, "considering", quantity: 5)
        form = change_to(deck, "modern")

        expect(form.save).to be(true)

        expect([ first.reload.location_id, second.reload.location_id ]).to eq([ considering.id, considering.id ])
        expect(main.reload.location_id).to eq(deck.zone("main").id)
        expect(there.reload).to have_attributes(location_id: considering.id, quantity: 5)
        expect(zone_keys(deck)).not_to include("commander")
        expect([ form.moved, form.considering_name ]).to eq([ 3, "Considering" ])
      end

      it "removes an empty dropped zone and moves nothing (AC-2.1a)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "main", quantity: 2)
        form = change_to(deck, "modern")

        expect { form.save }.not_to change { Lot.pluck(:id, :quantity, :location_id, :lot_key) }
        expect(zone_keys(deck)).not_to include("commander")
        expect([ form.moved, lot.reload.quantity ]).to eq([ 0, 2 ])
      end

      it "merges a moved lot into the lot of its identity already in Considering, which survives; a lot alone keeps its id (AC-2.2)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        there = create_lot_in_zone(deck, "considering", entry:, quantity: 3)
        merging = create_lot_in_zone(deck, "commander", entry:, quantity: 2)
        alone = create_lot_in_zone(deck, "commander", quantity: 1)

        change_to(deck, "modern").save!

        expect(there.reload).to have_attributes(quantity: 5, location_id: considering.id)
        expect(Lot.exists?(merging.id)).to be(false)
        expect(alone.reload.location_id).to eq(considering.id)
      end

      it "counts the copies that moved, merged ones included, and not those already in Considering (AC-2.5)" do
        entry = create(:mtg_printing).entry
        create_lot_in_zone(deck, "considering", entry:, quantity: 3)
        create_lot_in_zone(deck, "commander", entry:, quantity: 2)

        form = change_to(deck, "modern")
        form.save!

        expect(form.moved).to eq(2)
      end

      it "keys a moved lot by the Considering zone's id, as Lot.key_for builds it, and exports it there (AC-2.4)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", finish: "foil", condition: "near_mint", price_paid_cents: 250, quantity: 1)

        change_to(deck, "modern").save!

        expect(lot.reload.lot_key).to eq(Lot.key_for("foil", "near_mint", 250, considering.id))
        exported = CollectionExport.new(account:, at: Time.utc(2026, 11, 10)).to_json
        expect(JSON.parse(exported)["lots"].map { it["location"] }).to eq([ { "deck" => "Izzet Tempo", "zone" => "considering" } ])
      end

      it "holds as many copies after as before and touches no other lot (AC-2.7)", :aggregate_failures do
        create_lot_in_zone(deck, "commander", quantity: 2)
        create_lot_in_zone(deck, "main", quantity: 3)
        other = create(:deck, account:, name: "Other", format: "commander")
        elsewhere = create_lot_in_zone(other, "commander", quantity: 7)
        unplaced = Lot.add!(account:, entry: create(:mtg_printing).entry, quantity: 1)
        stamps = [ elsewhere.reload.updated_at, unplaced.reload.updated_at ]

        expect { change_to(deck, "modern").save! }.not_to change { deck.holdings.copies }
        expect([ elsewhere.reload.updated_at, unplaced.reload.updated_at ]).to eq(stamps)
        expect(elsewhere.location_id).to eq(other.zone("commander").id)
      end

      it "writes the same number of statements for 3 lots and for 30 when none merges (NFR; a characterization, not a first-red example)" do
        few = create(:deck, account:, name: "Few", format: "commander")
        3.times { create_lot_in_zone(few, "commander", quantity: 1) }
        many = create(:deck, account:, name: "Many", format: "commander")
        30.times { create_lot_in_zone(many, "commander", quantity: 1) }

        expect(count_queries { change_to(many, "modern").save! }).to eq(count_queries { change_to(few, "modern").save! })
      end

      it "refuses, changing nothing, when a merge would pass 9,999 copies (AC-2.6)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        create_lot_in_zone(deck, "considering", entry:, quantity: 9_999)
        create_lot_in_zone(deck, "commander", entry:, quantity: 1)
        before = [ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]

        expect { change_to(deck, "modern").save }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot.entry).to eq(entry) }

        expect(deck.reload.format).to eq("commander")
        expect([ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]).to eq(before)
      end

      it "does not call a refused change a change: changed? is false and nothing moved (AC-2.6)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        create_lot_in_zone(deck, "considering", entry:, quantity: 9_999)
        create_lot_in_zone(deck, "commander", entry:, quantity: 1)
        form = change_to(deck, "modern")

        expect { form.save }.to raise_error(Lot::CapExceeded)

        expect([ form.changed?, form.moved ]).to eq([ false, 0 ])
      end

      it "leaves everything as it was when a write fails part way, and does not call it a refusal (AC-2.8)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", quantity: 2)
        allow(Location).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "disk full")

        expect { change_to(deck, "modern").save }.to raise_error(ActiveRecord::StatementInvalid)

        expect(deck.reload.format).to eq("commander")
        expect(lot.reload.location_id).to eq(deck.zone("commander").id)
        expect(zone_keys(deck)).to include("commander")
      end

      it "gives a deck with no Considering row one, from the registration, before the lots move into it (AC-2.10)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", quantity: 2)
        deck.zone("considering").delete

        change_to(deck, "modern").save!

        expect(lot.reload.location_id).to eq(deck.zone("considering").id)
      end

      it "keeps Considering the same row and keeps the lots in it (AC-2.10)", :aggregate_failures do
        there = create_lot_in_zone(deck, "considering", quantity: 5)

        expect { change_to(deck, "modern").save! }.not_to change { deck.zone("considering").id }
        expect(there.reload.location_id).to eq(deck.zone("considering").id)
      end
    end

    it "makes one lot of two dropped zones' lots of one identity (AC-2.3)", :aggregate_failures do
      fake_vocabulary
      deck = create(:deck, account:, pair: "fake/f")
      entry = create(:mtg_printing).entry
      create_lot_in_zone(deck, "a", entry:, quantity: 2)
      create_lot_in_zone(deck, "b", entry:, quantity: 3)

      form = described_class.new(deck:, format: "fake/g")
      form.save!

      lots = deck.zone("considering").lots
      expect(lots.map { [ it.catalog_entry_id, it.quantity ] }).to eq([ [ entry.id, 5 ] ])
      expect([ form.moved, zone_keys(deck) ]).to eq([ 5, [ "considering" ] ])
    end

    it "refuses, changing nothing, when lots of one identity from two dropped zones would pass 9,999 copies together (AC-2.6)", :aggregate_failures do
      fake_vocabulary
      deck = create(:deck, account:, pair: "fake/f")
      entry = create(:mtg_printing).entry
      create_lot_in_zone(deck, "a", entry:, quantity: 5_000)
      create_lot_in_zone(deck, "b", entry:, quantity: 5_000)
      before = [ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]

      expect { described_class.new(deck:, format: "fake/g").save }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot.entry).to eq(entry) }

      expect(deck.reload).to have_attributes(collectible_type: "fake", format: "f")
      expect([ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]).to eq(before)
    end

    it "brings an undo of an earlier bulk removal back without a location once its zone is gone (AC-2.9)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      lot = create_lot_in_zone(deck, "commander", quantity: 2)
      session = account.user.sessions.create!
      selection = BulkSelection.for(session)
      selection.record!(shown_ids: [ lot.id ], ticked_ids: [ lot.id ], header_rendered: false, header_ticked: false)
      removal = BulkRemoval.remove!(selection)

      change_to(deck, "modern").save!
      undone = removal.undo!(sort: CollectionTable::Sort.parse(nil, nil))

      expect(undone.unplaced).to eq(1)
      expect(account.lots.sole).to have_attributes(location_id: nil, quantity: 2)
    end

    it "exports the new format and zones, and the file has nothing to change (AC-1.8)", :aggregate_failures do
      deck = create(:deck, account:, name: "Krenko", format: "commander")
      create_lot_in_zone(deck, "commander", quantity: 2)
      create_lot_in_zone(deck, "main", quantity: 1)
      change_to(deck, "modern").save!

      data = JSON.parse(CollectionExport.new(account: account.reload, at: Time.utc(2026, 11, 10)).to_json)

      expect(data["decks"]).to eq([ { "name" => "Krenko", "collectible_type" => "mtg", "format" => "modern" } ])
      expect(data["lots"].map { it["location"] }).to contain_exactly({ "deck" => "Krenko", "zone" => "considering" }, { "deck" => "Krenko", "zone" => "main" })
      expect(CollectionImport.new(account:, file: StringIO.new(JSON.generate(data))).plan.nothing_to_change?).to be(true)
    end
  end

  describe "proxies (spec 068 Story 6)" do
    let(:deck) { create(:deck, account:, name: "Elves", format: "commander") }
    let(:entry) { create(:mtg_printing).entry }

    def proxy_in(zone, entry: self.entry, finish: "foil", quantity: 1) = proxy_in_deck(deck, zone, entry:, finish:, quantity:)
    def proxy_in_deck(deck, zone, entry: self.entry, finish: "foil", quantity: 1) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish:, quantity:)

    it "moves the proxies of a dropped zone into Considering and leaves the others where they were (AC-6.1)", :aggregate_failures do
      commander = proxy_in("commander", quantity: 2)
      main = proxy_in("main", entry: create(:mtg_printing).entry)
      kept = proxy_in("considering", entry: create(:mtg_printing).entry)
      change = change_to(deck, "modern")

      change.save!

      considering = deck.reload.zone("considering")
      expect(commander.reload.zone).to eq(considering)
      expect([ main.reload.zone, kept.reload.zone ]).to eq([ deck.zone("main"), considering ])
      expect(deck.zones.pluck(:zone)).not_to include("commander")
      expect(change.proxies_moved).to eq(2)
      expect(Deck::Proxy.count).to eq(3)
    end

    it "merges a moved proxy into the proxy of its printing and finish already in Considering, which survives (AC-6.2)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      there = proxy_in("considering", quantity: 3)

      change_to(deck, "modern").save!

      expect(Deck::Proxy.pluck(:id, :quantity)).to eq([ [ there.id, 5 ] ])
      expect { moved.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps a moved proxy's own row (same id) when Considering has none of that printing and finish (AC-6.2)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      proxy_in("considering", finish: "nonfoil", quantity: 3) # another finish of the same printing: not a merge

      change_to(deck, "modern").save!

      expect(moved.reload.zone).to eq(deck.zone("considering"))
      expect(Deck::Proxy.count).to eq(2)
    end

    it "makes one proxy of those of one printing and finish from several dropped zones (AC-6.2)", :aggregate_failures do
      fake_vocabulary # the helper's vocabulary also answers `finishes_for` and `finish_label`
      other = create(:deck, account:, name: "Fake deck", pair: "fake/f")
      entry = create(:catalog_entry, collectible_type: "fake")
      a = create(:deck_proxy, zone: other.zone("a"), account:, entry:, finish: nil, quantity: 2)
      b = create(:deck_proxy, zone: other.zone("b"), account:, entry:, finish: nil, quantity: 3)

      change = described_class.new(deck: other, format: "fake/g")
      change.save!

      expect(Deck::Proxy.where(location_id: other.zone("considering").id).pluck(:id, :quantity)).to eq([ [ a.id, 5 ] ])
      expect { b.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(change.proxies_moved).to eq(5)
    end

    it "refuses a move past 9,999 naming the proxy, and writes nothing (AC-6.4)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 5_000)
      proxy_in("considering", quantity: 5_000)

      expect { change_to(deck, "modern").save }.to raise_error(Deck::Proxy::CapExceeded) { |error| expect(error.proxy.id).to eq(moved.id) }

      expect(deck.reload.format).to eq("commander")
      expect(moved.reload.zone).to eq(deck.zone("commander"))
      expect(Deck::Proxy.pluck(:quantity).sort).to eq([ 5_000, 5_000 ])
    end

    describe "with two proxies over the cap (AC-6.4)" do
      def printing(name: "Bolt", set: "mh2", number: "1", language: "en")
        catalog_set = Catalog::Set.find_by(code: set) || create(:catalog_set, code: set)
        create(:mtg_printing, entry: create(:catalog_entry, name:, number:, set: catalog_set, language:)).entry
      end

      # A proxy of the entry in the dropped zone, with one of the same printing and finish in Considering, so the move would pass 9,999.
      def breach(entry, finish: "foil")
        proxy_in("considering", entry:, finish:, quantity: 5_000)
        proxy_in("commander", entry:, finish:, quantity: 5_000)
      end

      def refused
        change_to(deck, "modern").save
      rescue Deck::Proxy::CapExceeded => error
        error.proxy
      end

      it "names the first by card name, not the one made first" do
        ant = breach(printing(name: "Ant"))
        breach(printing(name: "Zed"))

        expect(refused).to eq(ant)
      end

      it "breaks a tie of name, set and number by language, ascending (en before ja)" do
        breach(printing(language: "ja")) # made first, so only the language puts the English one ahead
        english = breach(printing(language: "en"))

        expect(refused).to eq(english)
      end

      it "breaks a tie of name by set code" do
        breach(printing(set: "zzz"))
        early = breach(printing(set: "aaa"))

        expect(refused).to eq(early)
      end

      it "then by collector number as a number" do
        breach(printing(number: "10"))
        nine = breach(printing(number: "9"))

        expect(refused).to eq(nine)
      end

      it "then by finish" do
        entry = printing
        breach(entry, finish: "nonfoil")
        foil = breach(entry, finish: "foil")

        expect(refused).to eq(foil)
      end
    end

    it "shows the lots' refusal first when both would pass the cap (AC-6.5)" do
      lot_entry = create(:mtg_printing).entry
      Lot.add!(account:, entry: lot_entry, location: deck.zone("commander"), quantity: 9_000, finish: "foil")
      Lot.add!(account:, entry: lot_entry, location: deck.zone("considering"), quantity: 9_000, finish: "foil")
      proxy_in("commander", quantity: 9_000)
      proxy_in("considering", quantity: 9_000)

      expect { change_to(deck, "modern").save }.to raise_error(Lot::CapExceeded)
    end

    it "leaves a proxy where it is, with its id and quantity, when the new format has the same zones, and counts none moved (AC-6.6)", :aggregate_failures do
      modern = create(:deck, account:, name: "Plain", format: "modern")
      proxy = proxy_in_deck(modern, "main", quantity: 7)
      change = change_to(modern, "pauper")

      change.save!

      expect(proxy.reload).to have_attributes(location_id: modern.zone("main").id, quantity: 7)
      expect([ change.proxies_moved, Deck::Proxy.count ]).to eq([ 0, 1 ])
    end

    it "rolls the proxies back with the deck when the change fails part way (AC-6.7)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 4)
      allow(Location).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "disk full") # the step after the move adds Modern's Sideboard, as spec 064 AC-2.8's example fails it

      expect { change_to(deck, "modern").save }.to raise_error(ActiveRecord::StatementInvalid)

      expect(moved.reload.zone).to eq(deck.zone("commander"))
      expect(deck.reload.format).to eq("commander")
    end

    it "moves the proxies into the Considering the change makes for a deck that has none (AC-6.8)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      deck.zone("considering").delete # a deck with no Considering row (spec 064 AC-2.10's case): no lot is in it

      change_to(deck.reload, "modern").save!

      expect(moved.reload.zone).to eq(deck.zone("considering"))
    end
  end
end
