require "rails_helper"

RSpec.describe "Lots", type: :request do
  let(:user) { create(:user) }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
  let(:added) { "Lightning Bolt (#{entry.set.code.upcase} · 146)" }

  before { sign_in_as(user) }

  it "uses the page head and the detail page layout on every lot page", :aggregate_failures do
    lot = create(:lot, account: user.account, entry:)
    [ new_catalog_entry_lot_path(entry), edit_lot_path(lot) ].each do |path|
      get path
      expect(response.body).to include('<div class="c-pagehead">'), "#{path} has no page head"
    end
    get new_lot_removal_path(lot)
    expect(response.body).to include('<main class="c-main c-page">')
  end

  # AC-2.7: lot pages are detail pages whose Back link returns to the printing's card page.
  it "gives every lot page a detail header that goes back to the card page", :aggregate_failures do
    lot = create(:lot, account: user.account, entry:)
    { {} => catalog_entry_path(entry), { from: "collection" } => catalog_entry_path(entry, from: "collection") }.each do |context, card_page|
      [ new_catalog_entry_lot_path(entry, **context), edit_lot_path(lot, **context), new_lot_removal_path(lot, **context) ].each do |path|
        get path
        header = Nokogiri::HTML5(response.body).at_css("header.c-appbar")
        expect(header&.[]("class").to_s.split).to include("c-appbar--detail"), "#{path} has no detail header"
        expect(header&.at_css('a[aria-label="Back"]')&.[]("href")).to eq(card_page), "#{path} doesn't go back to #{card_page}"
        expect(header&.at_css(".c-appbar__add")).to be_nil, "#{path} shows the add button"
      end
    end
  end

  describe "adding" do
    it "returns 404 for an unknown printing" do
      get new_catalog_entry_lot_path("nope")
      expect(response).to have_http_status(:not_found)
    end

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

    it "links each invalid field to its message", :aggregate_failures do
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "0", finish: "etched", condition: "mint", price_paid: "1.234" } }
      page = Nokogiri::HTML5(response.body)
      { quantity: "Quantity must be a whole number", finish: "Finish isn't available", condition: "Condition isn't a known condition",
        price_paid: "Price paid must be a non-negative amount" }.each do |field, message|
        ids = page.at_css(%([name="lot[#{field}]"]))&.[]("aria-describedby").to_s.split
        expect(ids).not_to be_empty, "lot[#{field}] has no aria-describedby"
        expect(ids.map { |id| page.at_css("##{id}")&.text }.join(" ")).to include(message)
      end
    end

    it "doesn't describe valid fields by an error" do
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "0" } }
      expect(Nokogiri::HTML5(response.body).at_css('[name="lot[condition]"]')["aria-describedby"]).to be_nil
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

  describe "from the collection table" do
    let(:table) { collection_path(view: "table", q: "bolt", sort: "price", dir: "desc", page: 2) }
    let(:lot) { create(:lot, account: user.account, entry:) }

    it "returns to the table after saving, or from Cancel and Back", :aggregate_failures do
      get edit_lot_path(lot, from: "collection", return_to: table)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css('header a[aria-label="Back"]')["href"]).to eq(table)
      expect(page.at_css("form.c-form")["action"]).to eq(lot_path(lot, from: "collection", return_to: table))
      expect(page.at_css(".c-form__actions a")["href"]).to eq(table)
      patch lot_path(lot, from: "collection", return_to: table), params: { lot: { quantity: 2 } }
      expect(response).to redirect_to(table)
      follow_redirect!
      expect(response.body).to include("Saved.")
    end

    it "returns to the table after removing, or from Cancel and Back", :aggregate_failures do
      get new_lot_removal_path(lot, from: "collection", return_to: table)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css('header a[aria-label="Back"]')["href"]).to eq(table)
      expect(page.at_css(".c-confirm a.c-btn--secondary")["href"]).to eq(table)
      expect(page.at_css(".c-confirm form")["action"]).to eq(lot_path(lot, from: "collection", return_to: table))
      delete lot_path(lot, from: "collection", return_to: table)
      expect(response).to redirect_to(table)
      expect(flash[:notice]).to eq("Removed 1 × Lightning Bolt (#{entry.set.code.upcase} · 146) from your collection.")
    end

    it "ignores a return path off this instance", :aggregate_failures do
      patch lot_path(lot, return_to: "https://elsewhere.example/collection"), params: { lot: { quantity: 2 } }
      expect(response).to redirect_to(catalog_entry_path(entry))
      get edit_lot_path(lot, return_to: "https://elsewhere.example/collection")
      expect(Nokogiri::HTML5(response.body).at_css("form.c-form")["action"]).to eq(lot_path(lot))
    end
  end
end
