require "rails_helper"

# Spec 064 Stories 1 and 2: changing a deck's format makes its zones the new format's and moves the lots of dropped zones
# into Considering, all or nothing.
RSpec.describe Deck::FormatChange, type: :model do
  let(:account) { create(:user).account }

  def change_to(deck, key) = described_class.new(deck:, format: "mtg/#{key}") # not `change`: that is RSpec's matcher
  def zone_keys(deck) = deck.zones.pluck(:zone)
  def written = [ Location.count, Deck.count, Lot.count ]

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
  end
end
