require "rails_helper"

# Spec 071 Stories 2 to 5: what the Add to deck form shows and does, on the real database.
RSpec.describe Deck::Addition, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:zone) { deck.zone("main") }
  let(:shown) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

  def addition(use: nil, quantity: "1", zone_id: zone.id.to_s, entry: shown) = described_class.new(account:, entry:, zone_id:, quantity:, use:)
  def lot_in(place, quantity:, **attrs) = create(:lot, account:, entry: shown, quantity:, location: place, **attrs)

  describe "#uses" do
    it "offers My copies first when copies are free, then one proxy per finish in the vocabulary's order (decision 9)", :aggregate_failures do
      lot_in(nil, quantity: 1)
      expect(addition.uses.map(&:value)).to eq(%w[copies proxy:nonfoil proxy:foil])
      expect(addition.chosen).to be_nil
    end

    it "offers no My copies when nothing is free, and chooses the only option (spec 060 decision 14)", :aggregate_failures do
      one_finish = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[nonfoil]).entry
      subject = addition(entry: one_finish)
      expect(subject.uses.map(&:value)).to eq(%w[proxy:nonfoil])
      expect(subject.chosen).to eq("proxy:nonfoil")
    end

    it "offers one proxy with no finish for a printing that lists none, already chosen", :aggregate_failures do
      none = create(:mtg_printing, entry: create(:catalog_entry), finishes: []).entry
      expect(addition(entry: none).uses.map(&:value)).to eq(%w[proxy])
      expect(addition(entry: none).chosen).to eq("proxy")
    end

    it "keeps what was submitted as the chosen option, unless it is no longer one (decision 11)", :aggregate_failures do
      expect(addition(use: "proxy:foil").chosen).to eq("proxy:foil")

      one_finish = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[nonfoil]).entry
      expect(addition(use: "copies", entry: one_finish).chosen).to eq("proxy:nonfoil") # nothing is free, so My copies isn't drawn
    end
  end

  describe "#save with My copies" do
    let(:blue) { create(:location, account:, name: "Blue binder") }

    it "moves part of the first lot and leaves the rest and another printing's lot where they were (AC-3.1)", :aggregate_failures do
      red = create(:location, account:, name: "Red box")
      other = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", identity: shown.identity, released_on: Date.new(1999, 1, 1)), finishes: %w[nonfoil]).entry
      elsewhere = create(:lot, account:, entry: other, quantity: 1, location: red)
      stay = lot_in(blue, quantity: 3)
      subject = addition(use: "copies", quantity: "1")

      expect(subject.save).to be(true)
      expect(elsewhere.reload).to have_attributes(location: red, quantity: 1)
      expect(stay.reload.quantity).to eq(2)
      expect(stay.location).to eq(blue)
      expect(account.lots.find_by(location: zone).quantity).to eq(1)
      expect(subject.count).to eq(1)
      expect(subject.zone).to eq(zone)
    end

    it "takes the shown printing's lots before another printing's, whole lots first (AC-3.2, AC-3.7)", :aggregate_failures do
      other = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", identity: shown.identity, released_on: Date.new(1999, 1, 1)), finishes: %w[nonfoil]).entry
      mine = lot_in(blue, quantity: 1)
      theirs = create(:lot, account:, entry: other, quantity: 2)

      expect(addition(use: "copies", quantity: "2").save).to be(true)
      expect(mine.reload.location).to eq(zone)
      expect(theirs.reload.quantity).to eq(1)
      expect(account.lots.where(location: zone).sum(:quantity)).to eq(2)
    end

    it "moves whole lots keeping their ids and fields when the zone has no lot of their identity (AC-3.2)", :aggregate_failures do
      first = lot_in(blue, quantity: 2, finish: "foil", price_paid_cents: 150)
      second = lot_in(nil, quantity: 1)
      before = [ first, second ].map { it.attributes.slice("id", "finish", "condition", "price_paid_cents", "quantity") }

      expect(addition(use: "copies", quantity: "3").save).to be(true)
      expect([ first, second ].map { it.reload.attributes.slice("id", "finish", "condition", "price_paid_cents", "quantity") }).to eq(before)
      expect([ first, second ].map { it.location }).to eq([ zone, zone ])
    end

    it "refuses a count over the free copies with the free total, changing nothing (AC-3.3)", :aggregate_failures do
      lot_in(blue, quantity: 3)
      subject = addition(use: "copies", quantity: "4")

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 3." ])
      expect(account.lots.where(location: zone)).to be_empty
    end

    it "judges the count at the write, on what is free then (AC-3.8)", :aggregate_failures do
      a = lot_in(blue, quantity: 1)
      lot_in(nil, quantity: 1)
      subject = addition(use: "copies", quantity: "2")
      subject.free # the page was drawn with two free
      Lot::MoveIntoZone.new(account:, zone:, picks: [ [ a, 1 ] ]).call! # another tab took one

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 1." ])
    end

    it "says so when nothing is free any more, on the choice (AC-3.8)", :aggregate_failures do
      subject = addition(use: "copies", quantity: "1")

      expect(subject.save).to be(false)
      expect(subject.errors[:use]).to eq([ "You have no free copy of Lightning Bolt to use." ])
    end

    it "merges into the zone's lot of the same identity (AC-3.4)", :aggregate_failures do
      create(:lot, account:, entry: shown, quantity: 2, location: zone)
      lot_in(blue, quantity: 1)
      lot_in(nil, quantity: 1)

      expect(addition(use: "copies", quantity: "2").save).to be(true)
      expect(account.lots.where(location: zone).pluck(:quantity)).to eq([ 4 ])
    end

    it "refuses past 9,999 in one lot of the zone, naming the lot and rolling the first move back (AC-3.5)", :aggregate_failures do
      create(:lot, account:, entry: shown, quantity: 9_995, finish: "foil", location: zone)
      first = lot_in(nil, quantity: 1)
      lot_in(nil, quantity: 10, finish: "foil")
      lot_in(blue, quantity: 1, finish: "nonfoil") # taken third: the cap is found on the second
      subject = addition(use: "copies", quantity: "12")

      expect(subject.save).to be(false)
      expect(subject.errors[:base]).to eq([ "Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(shown)}) would have more than 9,999 copies in one lot." ])
      expect(first.reload.location).to be_nil
    end

    it "names a lot the vocabulary no longer accepts, taken second of three, and writes nothing (AC-3.11)", :aggregate_failures do
      first = lot_in(nil, quantity: 1)
      broken = lot_in(nil, quantity: 1, finish: "foil")
      broken.update_columns(finish: "etched") # a catalog refresh dropped the finish: `Lot` now refuses to save it (spec 070's example does the same)
      third = lot_in(create(:location, account:, name: "Red box"), quantity: 1, finish: "nonfoil") # "" < "etched" < "nonfoil": the broken lot is taken second
      subject = addition(use: "copies", quantity: "3")

      expect(subject.save).to be(false)
      expect(subject.errors[:base]).to eq([ "Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(shown)}) can't be moved until it is edited." ])
      expect([ first, broken, third ].map { it.reload.location&.name }).to eq([ nil, nil, "Red box" ]) # the move judges before it writes, so none moved
    end

    it "names a lot whose condition the vocabulary no longer knows in the same way (AC-3.11)", :aggregate_failures do
      odd = lot_in(nil, quantity: 1)
      odd.update_columns(condition: "no_longer_a_condition")
      subject = addition(use: "copies", quantity: "1")

      expect(subject.save).to be(false)
      expect(subject.errors[:base].first).to end_with("can't be moved until it is edited.")
      expect(odd.reload.location).to be_nil
    end

    it "raises RecordNotFound when the zone was removed after the page opened (AC-3.12)" do
      lot_in(blue, quantity: 1)
      subject = addition(use: "copies")
      subject.groups # the page's read
      account.locations.where(id: zone.id).delete_all # removed in another tab (its lots, none here, would refuse this)

      expect { subject.save }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "changes no proxy, deck, location, other card's lot or other account's rows (AC-3.10)", :aggregate_failures do
      proxy = create(:deck_proxy, zone:, account:, entry: shown, quantity: 4)
      mine = lot_in(blue, quantity: 1)
      theirs = create(:lot, entry: shown)
      unrelated = create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 2)
      saved = decks = locations_written = nil
      proxies_written = write_statements_to("deck_proxies") do
        locations_written = write_statements_to("locations") do
          decks = write_statements_to("decks") { saved = addition(use: "copies").save }
        end
      end

      expect(saved).to be(true) # the positive control: the take did happen
      expect([ proxies_written, locations_written, decks ]).to all(be_empty)
      expect(mine.reload.location).to eq(zone)
      expect([ proxy.reload.quantity, theirs.reload.location, unrelated.reload.location ]).to eq([ 4, nil, nil ])
    end
  end

  describe "#save with a proxy" do
    it "adds a proxy of the shown printing and finish, merging into the zone's own (AC-4.1)", :aggregate_failures do
      first = addition(use: "proxy:foil", quantity: "2")
      expect(first.save).to be(true)
      expect(first.proxy).to have_attributes(quantity: 2, finish: "foil", entry: shown, zone: zone)

      again = addition(use: "proxy:foil", quantity: "3")
      expect(again.save).to be(true)
      expect(again.proxy.id).to eq(first.proxy.id)
      expect(again.proxy.quantity).to eq(5)
      expect(account.lots.count).to eq(0)
    end

    it "refuses a finish the printing doesn't list and a missing one, on the choice (AC-4.3)", :aggregate_failures do
      unlisted = addition(use: "proxy:etched")
      expect(unlisted.save).to be(false)
      expect(unlisted.errors[:use]).to eq([ "That finish isn't available for this printing." ])

      bare = addition(use: "proxy")
      expect(bare.save).to be(false)
      expect(bare.errors[:use]).to eq([ "Choose a finish." ])
      expect(account.deck_proxies.count).to eq(0)
    end

    it "refuses a quantity that isn't a whole number from 1 to 9,999, on How many (AC-4.4)", :aggregate_failures do
      %w[0 abc 1.5 10000 -1].each do |typed|
        subject = addition(use: "proxy:foil", quantity: typed)
        expect(subject.save).to be(false), typed
        expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 9,999." ]), typed
      end
    end

    it "refuses past 9,999 proxies, with spec 068's sentence on How many (AC-4.2)", :aggregate_failures do
      create(:deck_proxy, zone:, account:, entry: shown, finish: "foil", quantity: 9_990)
      subject = addition(use: "proxy:foil", quantity: "10")

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ Deck::Proxy::FULL_MESSAGE ])
      expect(account.deck_proxies.sole.quantity).to eq(9_990)
    end
  end

  describe "#save's other refusals" do
    it "asks for a zone and a choice on their own fields (AC-5.1)", :aggregate_failures do
      subject = addition(zone_id: "", use: nil)

      expect(subject.save).to be(false)
      expect(subject.errors[:zone_id]).to eq([ "Choose a deck and zone." ])
      expect(subject.errors[:use]).to eq([ "Choose what to use." ])
      expect(addition(use: "banana").tap(&:save).errors[:use]).to eq([ "Choose what to use." ])
    end

    it "raises RecordNotFound for a zone that isn't one of the account's offered zones (AC-5.2)", :aggregate_failures, :other_collecting do
      place = create(:location, account:)
      theirs = create(:deck).zone("main")
      elsewhere = create(:deck, account:, name: "Other deck", pair: "other/standard").zones.first
      [ place.id, deck.location_id, theirs.id, elsewhere.id, "12x" ].each do |bad|
        expect { addition(zone_id: bad.to_s, use: "proxy:foil").save }.to raise_error(ActiveRecord::RecordNotFound), bad.to_s
      end
      expect(account.deck_proxies.count).to eq(0)
    end
  end
end
