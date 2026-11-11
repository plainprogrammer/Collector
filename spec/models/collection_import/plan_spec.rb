require "rails_helper"

# Spec 028: what applying a file would do, and the fingerprint that ties an apply to its preview (decision 2).
RSpec.describe CollectionImport::Plan, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }

  def import(lots, **fields) = CollectionImport.new(account:, file: import_io(import_file(user, lots, **fields)))

  it "lists what applying does (FR-1)", :aggregate_failures do
    kept = held_lot(account, a, quantity: 3)
    edited = held_lot(account, b, quantity: 2)
    gone = held_lot(account, import_printing, quantity: 7)
    plan = import([ import_row(a, quantity: 3), import_row(b, quantity: 5, changed_at: "2026-10-02T10:00:00Z"), import_row(import_printing, quantity: 6) ]).plan

    expect(plan.added_rows.map(&:number)).to eq([ 3 ])
    expect(plan.changed_rows.map(&:number)).to eq([ 2 ])
    expect(plan.held_for(plan.changed_rows.first).id).to eq(edited.id)
    expect(plan.removed_lots.map(&:id)).to eq([ gone.id ])
    expect(plan.counts).to eq(added: 1, changed: 1, removed: 1)
    expect([ plan.nothing_to_change?, plan.removes? ]).to eq([ false, true ])
    expect(kept).to be_persisted
  end

  it "has nothing to change for a file the collection already holds (AC-1.5)", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    plan = import([ import_row(a, quantity: 3) ]).plan

    expect(plan.nothing_to_change?).to be(true)
    expect(import([], profile: { "name" => "x", "email_address" => "x@example.test", "collection_view" => "table" }).plan.nothing_to_change?).to be(false) # a view change alone is something
  end

  it "treats a lot with fractional times as unchanged against a row without them (AC-1.7)" do
    lot = held_lot(account, a, quantity: 3)
    lot.update_columns(created_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.25, updated_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.75)

    expect(import([ import_row(a, quantity: 3) ]).plan.nothing_to_change?).to be(true)
  end

  describe "the currency (spec 038 decision 7)" do
    it "has something to change for a file whose only difference is its currency, and nothing once it matches (AC-6.4, AC-6.5)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      plan = import([ import_row(a, quantity: 3) ], currency: "EUR").plan
      expect([ plan.nothing_to_change?, plan.writes_lots?, plan.removes?, plan.currency_change.to ]).to eq([ false, false, false, "EUR" ])

      account.update!(currency: "EUR")
      expect(import([ import_row(a, quantity: 3) ], currency: "EUR").plan.nothing_to_change?).to be(true)
    end

    it "keeps a plan's fingerprint without a change, and tells changes apart by both codes", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      same = import([ import_row(a, quantity: 3) ]).plan.fingerprint("sum")
      expect(same).to eq(Digest::SHA256.hexdigest(JSON.generate([ "sum", [], [], [], nil ]))) # what spec 028's plan wrote
      from_usd = import([ import_row(a, quantity: 3) ], currency: "EUR").plan.fingerprint("sum")
      account.update!(currency: "GBP")
      from_gbp = import([ import_row(a, quantity: 3) ], currency: "EUR").plan.fingerprint("sum")
      expect([ from_usd == same, from_gbp == from_usd ]).to eq([ false, false ])
    end
  end

  describe "#fingerprint (AC-3.7)" do
    def view_profile(view) = { "name" => user.name, "email_address" => user.email_address, "collection_view" => view }

    def fingerprint(checksum = "sum") = import([ import_row(a, quantity: 5), import_row(b, quantity: 1) ]).plan.fingerprint(checksum)

    it "is equal for two previews of the same file and collection", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      first = fingerprint
      expect(fingerprint).to eq(first)
      expect(lot).to be_persisted
    end

    it "differs for any change to a lot's quantity, either time or existence, to the file, or to the view", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      baseline = fingerprint

      lot.update_columns(quantity: 3)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(quantity: 2)
      expect(fingerprint).to eq(baseline)
      lot.update_columns(updated_at: lot.updated_at + 0.001)
      expect(fingerprint).not_to eq(baseline) # full precision, not truncated to the second
      lot.update_columns(updated_at: lot.updated_at - 0.001, created_at: lot.created_at + 1.hour)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(created_at: lot.created_at - 1.hour)
      expect(fingerprint("other")).not_to eq(baseline) # the stored file
      extra = held_lot(account, import_printing, quantity: 1)
      expect(fingerprint).not_to eq(baseline) # a removed lot appears
      extra.destroy!
      lot.destroy!
      expect(fingerprint).not_to eq(baseline)
      same = import([ import_row(a, quantity: 5) ], profile: view_profile("grid")).plan.fingerprint("sum")
      changing = import([ import_row(a, quantity: 5) ], profile: view_profile("table")).plan.fingerprint("sum")
      expect(changing).not_to eq(same) # the view change
    end
  end

  it "re-reads the collection on replan without parsing again, and becomes the import's plan", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    parsed = import([ import_row(a, quantity: 3) ])
    expect(parsed.plan.nothing_to_change?).to be(true) # as the preview saw it

    account.lots.update_all(quantity: 4)
    expect(parsed.plan.nothing_to_change?).to be(true) # memoized

    expect(parsed.replan.changed_rows.size).to eq(1)
    expect(parsed.plan.changed_rows.size).to eq(1)
    expect(parsed.changed.lots).to eq(1) # the page's counts follow the new plan
  end

  it "knows the catalog entry each row resolved to" do
    parsed = import([ import_row(a) ])

    expect(parsed.entry_id(parsed.rows.first)).to eq(a.id)
  end

  describe "locations (spec 029)" do
    def import_v2(lots, locations: [], **fields) = CollectionImport.new(account:, file: import_io(import_file_v2(user, lots, locations:, **fields)))

    it "has something to change for a file whose only change is a location, and nothing for one that matches (AC-9.4)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Box")

      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "Box" ]).plan.nothing_to_change?).to be(true)
      plan = import_v2([ import_row(a, quantity: 3) ], locations: [ "Box", "Crate" ]).plan
      expect([ plan.nothing_to_change?, plan.writes_lots?, plan.removes? ]).to eq([ false, false, false ])
      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "BOX" ]).plan.nothing_to_change?).to be(false) # a change of case alone
    end

    it "removes when it removes lots or locations, and writes lots only when a lot changes (AC-9.10, AC-9.17)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Old crate")
      only_locations = import_v2([ import_row(a, quantity: 3) ], locations: [])
      only_view = import_v2([ import_row(a, quantity: 3) ], locations: [ "Old crate" ], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "table" })
      lots = import_v2([ import_row(a, quantity: 4) ], locations: [ "Old crate" ])

      expect([ only_locations.plan.removes?, only_locations.plan.writes_lots? ]).to eq([ true, false ])
      expect([ only_view.plan.nothing_to_change?, only_view.plan.writes_lots? ]).to eq([ false, false ])
      expect([ lots.plan.removes?, lots.plan.writes_lots? ]).to eq([ false, true ])
    end

    it "leaves a version 1 file's plan and fingerprint to the lots (AC-9.3)", :aggregate_failures do
      create(:location, account:, name: "Box")
      plan = import([ import_row(a) ]).plan

      expect(plan.locations.counted?).to be(false)
      expect(plan.fingerprint("sum")).to eq(import([ import_row(a) ]).plan.fingerprint("sum"))
    end

    describe "#fingerprint (AC-9.9)" do
      def fingerprint(*names, lots: [ import_row(a) ]) = import_v2(lots, locations: names).plan.fingerprint("sum")

      it "is equal for two previews of one file and account, and differs for a location added, removed or respelled", :aggregate_failures do
        box = create(:location, account:, name: "box")
        baseline = fingerprint("Box", "New")

        expect(fingerprint("Box", "New")).to eq(baseline)
        create(:location, account:, name: "New") # added by another tab
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        Location.where(name: "New").destroy_all
        box.update!(name: "Box") # respelled, so the rename became unchanged
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        box.update!(name: "box")
        expect(fingerprint("Box", "New")).to eq(baseline)
        box.destroy!
        expect(fingerprint("Box", "New")).not_to eq(baseline)
      end

      it "differs for another file, and holds no id: a renamed, a removed and an unchanged location deleted and added again with the same spelling change nothing (AC-9.9, ruled 2026-10-21)", :aggregate_failures do
        [ "box", "Old crate", "Same" ].each { |name| create(:location, account:, name:) } # "box" is renamed to Box, "Old crate" is removed
        baseline = fingerprint("Box", "Same", "Other")

        expect(fingerprint("Box", "Same", "Another")).not_to eq(baseline)
        account.locations.each do |location|
          name = location.name
          location.destroy!
          create(:location, account:, name:) # a new id each, the same plan
        end
        expect(fingerprint("Box", "Same", "Other")).to eq(baseline)
      end
    end
  end

  describe "the place of a lot (spec 032)" do
    it "changes the fingerprint when a held lot's place changes, so a preview of the move is stale" do
      lot = held_lot(account, a, quantity: 3)
      file = import_file_v3(user, [ import_row(b, quantity: 1, location: nil) ])
      before = CollectionImport.new(account:, file: import_io(file)).plan.fingerprint("sum")
      lot.update!(location: create(:location, account:))

      expect(CollectionImport.new(account:, file: import_io(file)).plan.fingerprint("sum")).not_to eq(before)
    end
  end

  describe "decks (spec 062)" do
    def import_v4(lots = [ import_row(a, location: nil) ], decks: [], locations: [], **fields)
      CollectionImport.new(account:, file: import_io(import_file_v4(user, lots, decks:, locations:, **fields)))
    end

    def deck_of(name, format: "modern") = { "name" => name, "collectible_type" => "mtg", "format" => format }

    it "takes the decks into the plan: what a deck changes is something to change, a removed one removes, a lot is not written (AC-7.7)", :aggregate_failures do
      held_lot(account, a, quantity: 1)
      create(:deck, account:, name: "Old deck")
      plan = import_v4(decks: [ "Izzet Tempo" ]).plan

      expect(plan.decks.added.map(&:name)).to eq([ "Izzet Tempo" ])
      expect(plan.decks.removed.map(&:name)).to eq([ "Old deck" ])
      expect([ plan.nothing_to_change?, plan.removes?, plan.writes_lots? ]).to eq([ false, true, false ])
    end

    it "has something to change for a file whose only difference is one deck, and nothing once the collection holds them (AC-7.7)", :aggregate_failures do
      held_lot(account, a, quantity: 1)
      only_deck = import_v4([ import_row(a, location: nil) ], decks: [ "Izzet Tempo" ]).plan
      expect([ only_deck.nothing_to_change?, only_deck.removes? ]).to eq([ false, false ])

      create(:deck, account:, name: "Izzet Tempo")
      expect(import_v4([ import_row(a, location: nil) ], decks: [ "Izzet Tempo" ]).plan.nothing_to_change?).to be(true)
      expect(import_v4([ import_row(a, location: nil) ], decks: [ "Izzet Tempo" ], currency: "EUR").plan.nothing_to_change?).to be(false)
    end

    it "judges every difference of a deck in the plan: added, renamed, format changed, both together, unchanged, removed (AC-7.2)", :aggregate_failures do
      %w[Same tempo Elves Gone].each { |name| create(:deck, account:, name:) }
      plan = import_v4(decks: [ "Same", "Tempo", deck_of("Elves", format: "commander"), "New" ]).plan

      expect(plan.decks.counts).to eq(added: 1, renamed: 1, format_changed: 1, unchanged: 1, removed: 1)
      expect(plan.decks.renamed.map { |renamed| [ renamed.held.name, renamed.name ] }).to eq([ %w[tempo Tempo] ])
      expect(plan.decks.format_changed.map { |changed| [ changed.held.name, changed.format ] }).to eq([ %w[Elves commander] ])
    end

    describe "#fingerprint (AC-7.10)" do
      def fingerprint(*decks, **options) = import_v4(decks: decks, **options).plan.fingerprint("sum")

      it "differs for a deck added, removed, renamed or given another format between preview and apply, and for another file", :aggregate_failures do
        elves = create(:deck, account:, name: "Elves")
        baseline = fingerprint("Elves", "New")

        expect(fingerprint("Elves", "New")).to eq(baseline)
        expect(fingerprint("Elves", "Newer")).not_to eq(baseline) # another file
        create(:deck, account:, name: "New") # added by another tab: the file's deck is no longer added
        expect(fingerprint("Elves", "New")).not_to eq(baseline)
        Deck.joins(:location).find_by!(locations: { name: "New" }).remove!
        elves.rename("ELVES")
        expect(fingerprint("Elves", "New")).not_to eq(baseline) # respelled: it was unchanged, now renamed
        elves.rename("Elves")
        expect(fingerprint("Elves", "New")).to eq(baseline)
        elves.update!(format: "commander")
        expect(fingerprint("Elves", "New")).not_to eq(baseline) # its format
        elves.update!(format: "modern")
        elves.remove!
        expect(fingerprint("Elves", "New")).not_to eq(baseline) # a removed one is added again
      end

      it "holds no id: a renamed, a format-changed, an unchanged and a removed deck deleted and made again as they were change nothing", :aggregate_failures do
        { "izzet" => "modern", "Elves" => "commander", "Same" => "modern", "Old" => "modern" }.each { |name, format| create(:deck, account:, name:, format:) }
        files = [ "Izzet", deck_of("Elves", format: "pauper"), "Same", "Other" ]
        baseline = import_v4(decks: files).plan.fingerprint("sum")

        Deck.includes(:location).to_a.map { |deck| [ deck.name, deck.format ] }.each do |name, format|
          Deck.joins(:location).find_by!(locations: { name: }).remove!
          create(:deck, account:, name:, format:) # a new id each, the same plan
        end

        expect(import_v4(decks: files).plan.fingerprint("sum")).to eq(baseline)
      end

      it "keeps the fingerprint a version 1 to 3 plan had, whatever decks are held, with and without a currency change", :aggregate_failures do
        create(:deck, account:, name: "Izzet Tempo")
        row = import_row(a, location: nil)
        old = ->(*parts) { Digest::SHA256.hexdigest(JSON.generate([ "sum", [ [ 1, "added" ] ], [], [], nil, *parts ])) }

        v1 = CollectionImport.new(account:, file: import_io(import_file(user, [ import_row(a) ])))
        v3 = CollectionImport.new(account:, file: import_io(import_file_v3(user, [ row ], locations: [ "Box" ])))
        eur = CollectionImport.new(account:, file: import_io(import_file_v3(user, [ row ], locations: [ "Box" ], currency: "EUR")))

        expect(v1.plan.fingerprint("sum")).to eq(old.call)
        expect(v3.plan.fingerprint("sum")).to eq(old.call([ [ "Box" ], [], [] ]))
        expect(eur.plan.fingerprint("sum")).to eq(old.call([ [ "Box" ], [], [] ], [ "USD", "EUR" ]))
      end

      it "puts the decks' part after the locations' and before the currency change, only for a version 4 plan" do
        create(:deck, account:, name: "Old")
        plan = import_v4([ import_row(a, location: nil) ], locations: [ "Box" ], decks: [ "New" ], currency: "EUR").plan
        expected = Digest::SHA256.hexdigest(JSON.generate([ "sum", [ [ 1, "added" ] ], [], [], nil, [ [ "Box" ], [], [] ],
          [ [ "New" ], [], [], [ [ "Old" ] ] ], [ "USD", "EUR" ] ]))

        expect(plan.fingerprint("sum")).to eq(expected)
      end
    end

    it "re-reads the held decks on replan, so a deck made after the preview is part of the new plan", :aggregate_failures do
      parsed = import_v4(decks: [ "Izzet Tempo" ])
      expect(parsed.plan.decks.added.size).to eq(1)

      create(:deck, account:, name: "Izzet Tempo")

      expect(parsed.plan.decks.added.size).to eq(1) # memoized
      expect(parsed.replan.decks.added).to be_empty
      expect(parsed.plan.decks.unchanged).to eq(1)
    end
  end
end
