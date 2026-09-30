require "rails_helper"

RSpec.describe "Lots", type: :request do
  let(:user) { create(:user) }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
  let(:added) { "Lightning Bolt (#{entry.set.code.upcase} · 146)" }

  before { sign_in_as(user) }

  describe "adding" do
    it "offers only the printing's finishes and the condition scale", :aggregate_failures do
      get new_catalog_entry_lot_path(entry)
      expect(response.body).to include("Nonfoil", "Foil", "Near mint (NM)", "Damaged (DMG)", "Price paid per copy (USD)")
      expect(response.body).not_to include("Etched")
    end

    it "doesn't offer a finish when the printing lists none" do
      get new_catalog_entry_lot_path(create(:mtg_printing, finishes: []).entry)
      expect(response.body).not_to include('name="lot[finish]"')
    end

    it "adds copies with details and returns to the card page", :aggregate_failures do
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "2", finish: "foil", condition: "near_mint", price_paid: "4.00" } }
      expect(response).to redirect_to(catalog_entry_path(entry))
      expect(user.account.lots.sole).to have_attributes(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 400)
      follow_redirect!
      expect(response.body).to include("Added 2 × #{added} to your collection.")
    end

    it "rejects invalid values with a message per field", :aggregate_failures do
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "0", finish: "etched", condition: "mint", price_paid: "1.234" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Quantity must be a whole number from 1 to 9,999", "Finish isn&#39;t available for this printing",
        "Condition isn&#39;t a known condition", "Price paid must be a non-negative amount with at most two decimal places")
      expect(Lot.count).to eq(0)
    end

    it "reads quantities in base 10" do
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "010" } }
      expect(user.account.lots.sole.quantity).to eq(10)
    end

    it "refuses an add that would push a lot past 9,999", :aggregate_failures do
      create(:lot, account: user.account, entry:, quantity: 9_998)
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "2" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("One lot can hold at most 9,999 copies.")
    end

    it "ignores account values in submissions" do
      other = create(:user).account
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", account_id: other.id } }
      expect(Lot.sole.account).to eq(user.account)
    end
  end

  describe "editing" do
    let(:lot) { create(:lot, account: user.account, entry:, quantity: 3, condition: "near_mint") }

    it "prefills the form and saves valid values", :aggregate_failures do
      get edit_lot_path(lot)
      expect(response.body).to include('value="3"', '<option selected="selected" value="near_mint">')
      patch lot_path(lot), params: { lot: { quantity: "4", finish: "foil", condition: "near_mint", price_paid: "" } }
      expect(response).to redirect_to(catalog_entry_path(entry))
      expect(lot.reload.slice(:quantity, :finish).values).to eq([ 4, "foil" ])
      follow_redirect!
      expect(response.body).to include("Saved.")
    end

    it "rejects invalid values with 422 and leaves the lot unchanged", :aggregate_failures do
      patch lot_path(lot), params: { lot: { quantity: "lots", finish: "", condition: "", price_paid: "-1" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Quantity must be a whole number from 1 to 9,999", "Price paid must be a non-negative amount")
      expect(lot.reload.quantity).to eq(3)
    end

    it "merges into a matching lot", :aggregate_failures do
      foil = create(:lot, account: user.account, entry:, finish: "foil")
      plain = create(:lot, account: user.account, entry:, quantity: 2)
      patch lot_path(plain), params: { lot: { quantity: "2", finish: "foil", condition: "", price_paid: "" } }
      expect(response).to redirect_to(catalog_entry_path(entry))
      expect(foil.reload.quantity).to eq(3)
      expect(Lot.exists?(plain.id)).to be(false)
    end

    it "refuses a merge that would pass 9,999 copies", :aggregate_failures do
      foil = create(:lot, account: user.account, entry:, finish: "foil", quantity: 9_000)
      plain = create(:lot, account: user.account, entry:, quantity: 1_000)
      patch lot_path(plain), params: { lot: { quantity: "1000", finish: "foil", condition: "", price_paid: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("One lot can hold at most 9,999 copies.")
      expect([ foil.reload.quantity, plain.reload.finish ]).to eq([ 9_000, nil ])
    end
  end

  describe "removing" do
    it "confirms on its own page, then reports what was removed", :aggregate_failures do
      lot = create(:lot, account: user.account, entry:, quantity: 3)
      get new_lot_removal_path(lot)
      expect(response.body).to include("Remove 3 × Lightning Bolt?", %(action="#{lot_path(lot)}"))
      expect(response.body).to match(%r{<button[^>]*class="c-btn c-btn--danger"[^>]*>Remove</button>})
      delete lot_path(lot)
      follow_redirect!
      expect(response.body).to include("Removed 3 × #{added} from your collection.", "You don't have this card yet.")
    end

    it "keeps the collection context" do
      lot = create(:lot, account: user.account, entry:)
      delete lot_path(lot, from: "collection")
      expect(response).to redirect_to(catalog_entry_path(entry, from: "collection"))
    end
  end

  context "with another account's lot" do
    let(:foreign) { create(:lot, entry:, quantity: 5) }

    it "returns 404 for its edit form, update, removal page and removal", :aggregate_failures do
      get edit_lot_path(foreign)
      expect(response).to have_http_status(:not_found)
      patch lot_path(foreign), params: { lot: { quantity: "1" } }
      expect(response).to have_http_status(:not_found)
      get new_lot_removal_path(foreign)
      expect(response).to have_http_status(:not_found)
      delete lot_path(foreign)
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.quantity).to eq(5)
    end
  end
end
