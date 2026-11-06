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

  describe "choosing a place (spec 040)" do
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def long_box = @long_box ||= create(:location, account:, name: "Long box")

    def place(value, **extra) = patch(scanner_sitting_path, params: { sitting: { location_id: value } }.merge(extra), headers: stream)
    def picker = html.at_css("#scanner_sitting form[action='#{scanner_sitting_path}']")
    def chosen = picker.at_css("select#sitting_location_id option[selected]")

    it "shows the control alone with no sitting open: No location first and selected, then the locations in order (AC-1.1)", :aggregate_failures do
      long_box
      blue
      create(:location, name: "Another account's binder") # never listed (FR-1)
      get scanner_path
      expect(picker.at_css("label[for=sitting_location_id]").text).to eq("Put this sitting in")
      expect(picker.css("option").map { [ it.text, it["value"] ] }).to eq([ [ "No location", "" ], [ "Blue binder", blue.id.to_s ], [ "Long box", long_box.id.to_s ] ])
      expect(chosen.text).to eq("No location")
      expect(picker.at_css("input[type=submit], button[type=submit]")["value"] || picker.at_css("button").text).to eq("Set")
      expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "shows nothing of a sitting for an account with no locations (AC-3.1)", :aggregate_failures do
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
      expect(response.body).not_to include("Put this sitting in")
    end

    it "opens a sitting in the place, redrawing the panel with it chosen (AC-1.2)", :aggregate_failures do
      place(blue.id)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">', "This sitting&#39;s cards now go into Blue binder.")
      expect(response.body).not_to include('target="scanner_result"')
      expect(account.scanner_sitting.location).to eq(blue)
      expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("Blue binder")
    end

    it "changes the place of an open sitting, keeping its count and entries (AC-2.1)", :aggregate_failures do
      place(blue.id)
      entries = %w[a b c].map { add(it) }
      place(long_box.id)
      expect(account.scanner_sitting.reload).to have_attributes(location: long_box, entries:)
      expect(response.body).to include("This sitting: 3 cards")
    end

    it "names the place in the heading and on each entry, from the entry's lot as it is now (decisions 3, 4; AC-2.3)", :aggregate_failures do
      place(blue.id)
      moved = add("a")
      add("b", card: create(:mtg_printing, entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry)
      place(long_box.id)
      changed = add("c", card: create(:mtg_printing, entry: create(:catalog_entry, name: "Shock", set: mom, number: "9")).entry)
      moved.lot.update!(location: long_box)
      changed.lot.destroy!
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, in Long box")
      metas = html.css("#scanner_sitting > ul > li .c-list__meta").map { it.text.squish }
      expect(metas).to match([ /\AMOM · 9 · Foil · Added .+ ago\z/, /\AMOM · 7 · Foil · in Blue binder · Added .+ ago\z/, /\AMOM · 123 · Foil · in Long box · Added .+ ago\z/ ])
    end

    it "says where cards go in a placed sitting with no entries, and keeps spec 009's copy once all were undone (AC-1.2)", :aggregate_failures do
      place(blue.id)
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, in Blue binder")
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now go into Blue binder.")
      expect(html.at_css("#scanner_sitting ul")).to be_nil
      add("a").undo!
      get scanner_path
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Everything added in this sitting was undone.")
    end

    it "says nothing was added in a redrawn sitting with no entries and no place (plan Phase 4)", :aggregate_failures do
      long_box
      place(blue.id)
      delete location_path(blue)
      place(blue.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards")
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Nothing added yet.")
    end

    it "keeps the place on a reload (AC-1.7)" do
      place(blue.id)
      get scanner_path
      expect(chosen.text).to eq("Blue binder")
    end

    it "clears the place of a sitting with a card, and deletes one with none (AC-1.8)", :aggregate_failures do
      place(blue.id)
      add("a")
      place("")
      expect(account.scanner_sitting.reload.location).to be_nil
      expect(response.body).to include("This sitting&#39;s cards now go in no location.", "This sitting: 1 card")

      account.scanner_sitting.entries.sole.undo!
      place(blue.id)
      place("")
      expect(Scanner::Sitting.count).to eq(0)
      expect(response).to have_http_status(:ok)
      expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("No location")
      expect(response.body).not_to include("This sitting:", "now go")
    end

    it "answers 400 to a request with no place, changing nothing (AC-3.3)", :aggregate_failures do
      place(blue.id)
      patch scanner_sitting_path, params: { sitting: { other: "1" } }, headers: stream
      expect(response).to have_http_status(:bad_request)
      patch scanner_sitting_path, params: {}, headers: stream
      expect(response).to have_http_status(:bad_request)
      expect(account.scanner_sitting.reload.location).to eq(blue)
    end

    it "refuses another account's location, a removed one and a value that isn't a number, changing nothing (AC-4.1)", :aggregate_failures do
      place(blue.id)
      removed = create(:location, account:).tap(&:destroy!)
      [ create(:location).id, removed.id, "abc", "#{long_box.id}abc" ].each do |value|
        place(value)
        expect(response).to have_http_status(:unprocessable_content), value.inspect
        expect(CGI.unescapeHTML(response.body)).to include("That location isn't one of yours any more. Choose again.")
        expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("Blue binder")
      end
      expect(account.scanner_sitting.reload.location).to eq(blue)
    end

    it "refuses a bad value with no sitting open, opening none (AC-4.1)", :aggregate_failures do
      place(create(:location).id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(Scanner::Sitting.count).to eq(0)
    end

    it "ignores a sitting or account id in the request (AC-4.2)", :aggregate_failures do
      other = create(:user).account
      theirs = Scanner::Sitting.choose!(account: other, location: create(:location, account: other))
      place(blue.id, sitting_id: theirs.id, account_id: other.id)
      patch scanner_sitting_path, params: { sitting: { location_id: long_box.id, account_id: other.id, id: theirs.id } }, headers: stream
      expect(theirs.reload.location.account).to eq(other)
      expect(account.scanner_sitting.reload.location).to eq(long_box)
    end

    it "sends a signed-out visitor to sign in" do
      delete session_path
      place(blue.id)
      expect(response).to redirect_to(new_session_path)
    end

    it "redraws the panel with the control after an Undo (FR-1), and Undo takes the copy from the lot it went into (AC-2.2)", :aggregate_failures do
      place(blue.id)
      first = add("a")
      place(long_box.id)
      add("b")
      undo(first)
      expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("Long box")
      expect(account.lots.map { [ it.location&.name, it.quantity ] }).to eq([ [ "Long box", 1 ] ])
    end

    it "drops a sitting left with no entries and no place when its location is removed (AC-3.2, plan P1)", :aggregate_failures do
      place(blue.id)
      delete location_path(blue)
      expect(Scanner::Sitting.sole.location).to be_nil
      get scanner_path
      expect(Scanner::Sitting.count).to eq(0)
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
    end

    it "keeps a sitting with entries, all undone, when its last location goes, with Done and no control (AC-3.2)", :aggregate_failures do
      place(blue.id)
      add("a").undo!
      delete location_path(blue)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards")
      expect(response.body).to include(new_scanner_sitting_ending_path)
      expect(response.body).not_to include("Put this sitting in")
    end

    it "shows the summary with the control on No location after Done, and a place replaces it (AC-5.1, AC-5.2)", :aggregate_failures do
      place(blue.id)
      add("a")
      post scanner_sitting_ending_path
      follow_redirect!
      expect(html.at_css("#scanner_sitting").text.squish).to include("Added 1 card in this sitting")
      expect(chosen.text).to eq("No location")
      expect([ Scanner::Sitting.count, account.lots.sole.location ]).to eq([ 0, blue ])
      place(long_box.id)
      expect(response.body).not_to include("in this sitting.")
      expect(Scanner::Sitting.sole.location).to eq(long_box)
    end

    it "shows no control with the summary for an account with no locations (AC-5.2)" do
      add("a")
      post scanner_sitting_ending_path
      follow_redirect!
      expect(response.body).not_to include("Put this sitting in")
    end
  end

  it "returns to the scanner from the copy's Edit copy page (AC-3.4)" do
    entry = add("a")
    patch lot_path(entry.lot_id, return_to: scanner_path), params: { lot: { quantity: "1", finish: "foil", condition: "near_mint", price_paid: "" } }
    expect(response).to redirect_to(scanner_path)
  end
end
