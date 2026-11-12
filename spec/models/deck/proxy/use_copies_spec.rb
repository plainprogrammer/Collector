require "rails_helper"

# Spec 070 Stories 2 and 3 at the model: the free lots of a card, their groups, and the all-or-nothing replacement.
RSpec.describe Deck::Proxy::UseCopies, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { printing }
  let!(:proxy) { proxy_of(entry) }

  # Not memoized `let`s: the group has five at most (RSpec/MultipleMemoizedHelpers), so each finds what an earlier call made.
  def zone = deck.zone("main")
  def bolt = Catalog::Identity.find_by(name: "Lightning Bolt") || create(:catalog_identity, name: "Lightning Bolt")
  def place(name) = account.locations.find_by(name:) || create(:location, account:, name:)
  def binder = place("Blue binder")
  def box = place("Red box")
  def printing(set: "2x2", finishes: %w[foil nonfoil]) = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", identity: bolt, set: create(:catalog_set, code: set)), finishes:).entry
  def proxy_of(entry, quantity: 2, finish: "foil") = create(:deck_proxy, zone:, account:, entry:, finish:, quantity:)
  def lot_in(location, entry, quantity = 2, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def uses(proxy, typed = {}, shown = nil) = described_class.new(proxy:, typed:, shown: shown || typed.to_h { |id, _| [ id, account.lots.find(id).quantity.to_s ] })


  describe "#groups" do
    it "lists the account's free lots of the card: this printing and finish first, the rest under Other printings, in the card page's order", :aggregate_failures do
      same = lot_in(binder, entry, 1, finish: "foil")
      other_finish = lot_in(box, entry, 1, finish: "nonfoil")
      other_printing = lot_in(box, printing(set: "mm3"), 1, finish: "foil")
      lot_in(zone, entry, 1, finish: "foil")                                     # in this zone
      lot_in(deck.zone("considering"), entry, 1, finish: "foil")                 # in Considering
      create(:lot, entry: create(:mtg_printing, entry: create(:catalog_entry, name: "Other card")).entry, location: binder, account:) # another card
      other = create(:user).account
      create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 1, finish: "foil") # another account's

      groups = uses(proxy).groups

      expect(groups.map(&:first)).to eq([ "This printing", "Other printings" ])
      expect(groups.first.last.map { it.lot }).to eq([ same ])
      expect(groups.last.last.map { it.lot }).to contain_exactly(other_finish, other_printing)
    end

    it "leaves a group with no lot out, and is empty with no free lot", :aggregate_failures do
      expect(uses(proxy).groups).to eq([])
      lot_in(box, printing(set: "mm3"), 1)
      expect(uses(proxy).groups.map(&:first)).to eq([ "Other printings" ])
    end

    it "matches a proxy with no finish to a lot with none" do
      bare = printing(set: "bare", finishes: [])
      bare_proxy = proxy_of(bare, finish: nil)
      lot = lot_in(binder, bare, 1)

      expect(uses(bare_proxy).groups.map { |name, rows| [ name, rows.map(&:lot) ] }).to eq([ [ "This printing", [ lot ] ] ])
    end
  end

  describe "#save" do
    it "moves the chosen copies into the zone and lowers the proxy, keeping the proxy's id", :aggregate_failures do
      lot = lot_in(binder, entry, 3, finish: "foil")

      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(true)
      expect(form.used).to eq(1)
      expect(proxy.reload.quantity).to eq(1)
      expect(lot.reload).to have_attributes(location: binder, quantity: 2)
      expect(account.lots.find_by(location: zone)).to have_attributes(quantity: 1, finish: "foil")
    end

    it "removes the proxy when the copies used equal its count", :aggregate_failures do
      lot = lot_in(binder, entry, 3, finish: "foil")

      expect(uses(proxy, { lot.id.to_s => "2" }).save).to be(true)

      expect(Deck::Proxy.exists?(proxy.id)).to be(false)
      expect(account.lots.find_by(location: zone).quantity).to eq(2)
    end

    it "lowers the proxy and keeps it when fewer copies are used than it holds", :aggregate_failures do
      big = proxy_of(printing(set: "big"), quantity: 4)
      lot = lot_in(binder, big.entry, 1, finish: "foil")

      uses(big, { lot.id.to_s => "1" }).save

      expect(big.reload.quantity).to eq(3)
    end

    it "uses copies of several lots, other printings too, and the zone's row of them is of their own printing", :aggregate_failures do
      other = printing(set: "mm3")
      a = lot_in(binder, entry, 1, finish: "foil")
      b = lot_in(box, other, 1, finish: "foil")

      form = uses(proxy, { a.id.to_s => "1", b.id.to_s => "1" })

      expect(form.save).to be(true)
      expect(account.lots.where(location: zone).pluck(:catalog_entry_id)).to contain_exactly(entry.id, other.id)
    end

    it "refuses a number that isn't a whole number from 0 to the lot's copies, under that lot", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")

      %w[3 -1 1.5 abc].each do |typed|
        form = uses(proxy, { lot.id.to_s => typed })
        expect(form.save).to be(false), typed
        expect(form.rows.first.errors).to eq([ "Enter a number from 0 to 2." ]), typed
      end
      expect(lot.reload.location).to eq(binder)
    end

    it "treats blank as 0 and refuses a total of 0 or over the proxy's count, under the lots' fieldset", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")

      zero = uses(proxy, { lot.id.to_s => "" })
      over = uses(proxy, { lot.id.to_s => "3" })

      expect([ zero.save, over.save ]).to eq([ false, false ])
      expect([ zero.fieldset_errors, over.fieldset_errors ]).to eq([ [ "Enter a number from 1 to 2." ], [ "Enter a number from 1 to 2." ] ])
      expect(proxy.reload.quantity).to eq(2)
    end

    it "shows the sum's sentence only when no field or lot sentence applies", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "9" })

      form.save

      expect(form.fieldset_errors).to eq([])
      expect(form.rows.first.errors).to eq([ "Enter a number from 0 to 2." ])
    end

    # One example per cause: with the four in one fixture, any one of them alone refused the whole form and the others could break unseen.
    context "when a chosen lot changed since the page was shown" do
      def expect_changed(form)
        expect(form.save).to be(false)
        expect(form.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
        expect(proxy.reload.quantity).to eq(2)
        expect(account.lots.where(location: zone)).to be_empty
      end

      it "refuses a lot that was removed", :aggregate_failures do
        gone = lot_in(binder, entry, 1, finish: "foil")
        form = uses(proxy, { gone.id.to_s => "1" })
        gone.destroy!

        expect_changed(form)
      end

      it "refuses a lot taken into a zone", :aggregate_failures do
        taken = lot_in(box, entry, 1, finish: "foil")
        form = uses(proxy, { taken.id.to_s => "1" })
        taken.update!(location: deck.zone("sideboard"))

        expect_changed(form)
      end

      it "refuses a lot a split lowered since the page was shown", :aggregate_failures do
        part = lot_in(binder, entry, 5, finish: "nonfoil")
        form = uses(proxy, { part.id.to_s => "1" })
        part.update!(quantity: 3)

        expect_changed(form)
        expect(part.reload.quantity).to eq(3)
      end

      it "refuses another account's lot", :aggregate_failures do
        other = create(:user).account
        theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 1)

        expect_changed(uses(proxy, { theirs.id.to_s => "1" }, { theirs.id.to_s => "1" }))
        expect(theirs.reload.quantity).to eq(1)
      end
    end

    it "fails closed on a missing or malformed shown value, and ignores a lot with 0 whatever it is", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      other = lot_in(box, entry, 1, finish: "foil")

      missing = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: {})
      junk = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "two" })
      zeroes = described_class.new(proxy:, typed: { lot.id.to_s => "1", other.id.to_s => "0", "x" => "5" }, shown: { lot.id.to_s => "2" })

      expect([ missing.save, junk.save ]).to eq([ false, false ])
      expect(missing.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
      expect(zeroes.save).to be(true)
    end

    it "refuses the second submit of one form: the first split the lot, so its quantity is no longer the one shown", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")
      typed = { lot.id.to_s => "1" }
      shown = { lot.id.to_s => "5" } # what the page drew

      expect(described_class.new(proxy:, typed:, shown:).save).to be(true)
      again = described_class.new(proxy: Deck::Proxy.find(proxy.id), typed:, shown:)

      expect(again.save).to be(false)
      expect(again.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
      expect(lot.reload.quantity).to eq(4) # moved once
      expect(proxy.reload.quantity).to eq(1) # lowered once
    end

    it "writes again the shown quantities of a refused page from a fresh read, so the next submit succeeds", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")
      form = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "9" })

      expect(form.save).to be(false)
      row = form.groups.first.last.first
      expect(row).to have_attributes(shown: 5, typed: "1")

      retry_form = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => row.shown.to_s })
      expect(retry_form.save).to be(true)
    end

    it "refuses a lot over the cap in the zone under that lot's field, and writes nothing", :aggregate_failures do
      lot_in(zone, entry, 9_999, finish: "foil")
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.rows.first.errors).to eq([ "One lot can hold at most 9,999 copies." ])
      expect([ lot.reload.location, proxy.reload.quantity ]).to eq([ binder, 2 ])
    end

    it "refuses a lot the vocabulary can no longer save, under that lot's field", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      lot.update_columns(finish: "retired_finish")
      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.rows.first.errors).to eq([ "Edit this copy first: its finish or condition isn't offered any more." ])
    end

    it "shows a lot the vocabulary can't save beside a total over the count: the lot's sentence and not the sum's", :aggregate_failures do
      stale = lot_in(binder, entry, 2, finish: "foil")
      stale.update_columns(finish: "retired_finish")
      fine = lot_in(box, entry, 2, finish: "nonfoil")
      form = uses(proxy, { stale.id.to_s => "2", fine.id.to_s => "2" }) # a total of 4 over the count of 2

      expect(form.save).to be(false)
      expect(form.rows.find { it.lot == stale }.errors).to eq([ "Edit this copy first: its finish or condition isn't offered any more." ])
      expect(form.fieldset_errors).to eq([])
    end

    # A characterisation, not a red: it passes on arrival, since the lots drawn are read after the transaction (AC-3.15).
    it "builds the page of a refusal from a fresh read after the rollback (the first lot holds what it held)", :aggregate_failures do
      lot_in(zone, entry, 9_999, finish: "foil")
      first = lot_in(binder, entry, 2, finish: "nonfoil")
      second = lot_in(box, entry, 2, finish: "foil")
      form = uses(proxy, { first.id.to_s => "1", second.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.groups.flat_map(&:last).to_h { [ it.lot.id, it.lot.quantity ] }).to eq({ first.id => 2, second.id => 2 })
    end

    it "answers RecordNotFound for a proxy removed meanwhile, and writes nothing", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "1" })
      proxy.destroy!

      expect { form.save }.to raise_error(ActiveRecord::RecordNotFound)
      expect(lot.reload.location).to eq(binder)
    end
  end
end
