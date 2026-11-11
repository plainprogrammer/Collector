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
    end)
    Catalog.collecting["fake"] = "FakeDeckVocabulary"
  end

  after { Catalog.collecting.delete("fake") }

  describe "#save" do
    it "changes the type and format and nothing else when the formats share their zones (AC-1.3, AC-1.4)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      lot = create_lot_in_zone(deck, "main", quantity: 3)
      zone_ids = deck.zones.pluck(:id)
      location_id = deck.location_id
      form = change_to(deck, "pauper")

      expect(form.save).to be(true)

      expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "pauper")
      expect(deck.reload.location_id).to eq(location_id)
      expect(deck.zones.pluck(:id)).to eq(zone_ids)
      expect(lot.reload).to have_attributes(quantity: 3, location_id: deck.zone("main").id)
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
end
