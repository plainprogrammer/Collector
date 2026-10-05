require "rails_helper"

RSpec.describe "Scanner sittings", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let(:printing) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end
  let(:stream) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  before { sign_in_as(user) }

  def add(key, finish: "foil", to: account, card: printing) = Scanner::Sitting.add!(account: to, printing: card, finish:, reading_key: key * 32).entry
  def html = Nokogiri::HTML5(response.body)
  def undo(entry) = post(scanner_sitting_entry_undo_path(entry), headers: stream)

  describe "the list on the scanner" do
    it "lists the adds newest first, with the count, finish, time, Undo and the copy's details (AC-3.2, AC-3.4)", :aggregate_failures do
      plain = create(:mtg_printing, finishes: [], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry
      first = add("a", finish: "nonfoil")
      add("b")
      add("c", finish: "", card: plain)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards")
      rows = html.css("#scanner_sitting > ul > li")
      expect(rows.map { it.at_css(".c-list__meta").text.squish })
        .to match([ /\AMOM · 7 · — · Added .+ ago\z/, /\AMOM · 123 · Foil · Added .+ ago\z/, /\AMOM · 123 · Nonfoil · Added .+ ago\z/ ])
      expect(rows.last.at_css("a[data-scanner-event=details]")["href"]).to eq(edit_lot_path(first.lot_id, return_to: scanner_path))
      expect(rows.last.at_css("form.c-scanner__undo")["action"]).to eq(scanner_sitting_entry_undo_path(first))
      expect(html.at_css("#scanner_sitting a[href='#{new_scanner_sitting_ending_path}']").text).to eq("Done")
    end

    it "shows the 10 newest and the rest behind Show all (AC-3.2)", :aggregate_failures do
      12.times { add(format("%x", it)) }
      get scanner_path
      expect(html.css("#scanner_sitting > ul > li").size).to eq(10)
      expect(html.at_css("#scanner_sitting details summary").text.strip).to eq("Show all 12")
      expect(html.css("#scanner_sitting details li").size).to eq(2)
    end

    it "shows no list or Done without a sitting (AC-3.7)", :aggregate_failures do
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "marks an add whose lot went, with no Undo or details (AC-3.6)", :aggregate_failures do
      add("a")
      account.lots.sole.destroy!
      get scanner_path
      row = html.at_css("#scanner_sitting li")
      expect(row.text).to include("Changed in your collection")
      expect(row.css("form, a")).to be_empty
    end

    it "keeps each account's sitting to itself (AC-3.8)", :aggregate_failures do
      theirs = add("f", to: create(:user).account)
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
      undo(theirs)
      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.state).to eq(:added)
    end
  end

  describe "Undo" do
    it "takes one copy back in place and says so (AC-4.1)", :aggregate_failures do
      add("a")
      undo(add("b"))
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.", "This sitting: 1 card")
      expect(account.lots.sole.quantity).to eq(1)
    end

    it "ends the session's pending bulk Undo when the lot goes (AC-4.1, spec 006 AC-7.6)" do
      removal = BulkRemoval.create!(session: Session.sole, account:, copies: 1, lots_data: [ { "catalog_entry_id" => printing.id, "quantity" => 1 } ])
      undo(add("a"))
      expect(removal.reload).not_to be_undoable
    end

    it "refuses an add already undone, or whose copy changed (AC-4.2, AC-4.4)", :aggregate_failures do
      entry = add("a")
      undo(entry)
      undo(entry)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That card was already undone.")
      changed = add("b")
      account.lots.sole.destroy!
      undo(changed)
      expect(response).to have_http_status(:unprocessable_content)
      expect(CGI.unescapeHTML(response.body)).to include("That copy has changed in your collection, so it can't be undone here.")
    end

    it "answers 404 once the sitting has ended (Error Scenarios)" do
      entry = add("a")
      account.scanner_sitting.end!
      undo(entry)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Done" do
    it "asks first, then ends the sitting with a one-time summary (AC-3.5, AC-3.7)", :aggregate_failures do
      add("a")
      add("b").undo!
      get new_scanner_sitting_ending_path
      expect(html.at_css("h1").text).to eq("End this sitting?")
      expect(response.body).to include("You added 1 card in this sitting.")
      post scanner_sitting_ending_path
      expect(response).to redirect_to(scanner_path)
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(html.at_css("#scanner_sitting").text.squish).to include("Added 1 card in this sitting")
      expect(html.at_css("#scanner_sitting a[href='#{collection_path}']")).not_to be_nil
      get scanner_path
      expect(response.body).not_to include("Added 1 card in this sitting")
      expect([ Scanner::Sitting.count, account.lots.sum(:quantity) ]).to eq([ 0, 1 ])
    end

    it "says 0 when every add was undone (Error Scenarios)" do
      add("a").undo!
      post scanner_sitting_ending_path
      follow_redirect!
      expect(response.body).to include("Added 0 cards in this sitting")
    end

    it "goes back to the scanner without a sitting to end", :aggregate_failures do
      get new_scanner_sitting_ending_path
      expect(response).to redirect_to(scanner_path)
      post scanner_sitting_ending_path
      follow_redirect!
      expect(response.body).not_to include("in this sitting")
    end
  end

  it "returns to the scanner from the copy's Edit copy page (AC-3.4)" do
    entry = add("a")
    patch lot_path(entry.lot_id, return_to: scanner_path), params: { lot: { quantity: "1", finish: "foil", condition: "near_mint", price_paid: "" } }
    expect(response).to redirect_to(scanner_path)
  end
end
