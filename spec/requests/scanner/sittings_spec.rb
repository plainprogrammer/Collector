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
      expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
      expect(html.at_css("#scanner_sitting select#sitting_condition")).not_to be_nil
      expect(html.at_css("#scanner_sitting h2")).to be_nil
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
      expect(html.at_css("#scanner_sitting h2")).to be_nil
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
      expect(picker.at_css("label[for=sitting_location_id]").text).to eq("Location")
      expect(picker.css("select#sitting_location_id option").map { [ it.text, it["value"] ] }).to eq([ [ "No location", "" ], [ "Blue binder", blue.id.to_s ], [ "Long box", long_box.id.to_s ] ])
      expect(chosen.text).to eq("No location")
      expect(picker.at_css("input[type=submit], button[type=submit]")["value"] || picker.at_css("button").text).to eq("Set")
      expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "opens a sitting in the place, redrawing the panel with it chosen (AC-1.2)", :aggregate_failures do
      place(blue.id)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">', "Cards you scan now: condition not specified, in Blue binder.")
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
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: in Blue binder.")
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
      expect(response.body).to include("Cards you scan now: condition not specified, no location.", "This sitting: 1 card")

      account.scanner_sitting.entries.sole.undo!
      place(blue.id)
      place("")
      expect(Scanner::Sitting.count).to eq(0)
      expect(response).to have_http_status(:ok)
      expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("No location")
      expect(response.body).not_to include("This sitting:")
      expect(html.at_css("turbo-stream[target=status] .c-status__message").text.squish).to eq("Cards you scan now: condition not specified, no location.")
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
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "keeps a sitting with entries, all undone, when its last location goes, with Done and no control (AC-3.2)", :aggregate_failures do
      place(blue.id)
      add("a").undo!
      delete location_path(blue)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards")
      expect(response.body).to include(new_scanner_sitting_ending_path)
      expect(html.at_css("select#sitting_location_id")).to be_nil
      expect(html.at_css("select#sitting_condition")).not_to be_nil
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

    it "shows no control with the summary for an account with no locations (AC-5.2)", :aggregate_failures do
      add("a")
      post scanner_sitting_ending_path
      follow_redirect!
      expect(html.at_css("#scanner_sitting select#sitting_condition")).not_to be_nil
      expect(html.at_css("#scanner_sitting select#sitting_location_id")).to be_nil
    end
  end

  # Spec 062 D6, AC-5.1, AC-5.2, AC-5.7, AC-5.8a: the sitting's place is a place; a zone's or a deck's id is refused as any id
  # that isn't the account's is; an Undo leaves a lot that sits in a zone in its zone.
  describe "with a deck (spec 062)" do
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def place(value) = patch(scanner_sitting_path, params: { sitting: { location_id: value } }, headers: stream)
    def picker = html.at_css("#scanner_sitting form[action='#{scanner_sitting_path}']")

    it "lists No location and the places in the picker, never a deck or a zone (AC-5.1)", :aggregate_failures do
      deck
      create(:location, account:, name: "Long box")
      blue
      get scanner_path
      expect(picker.css("select#sitting_location_id option").map(&:text)).to eq([ "No location", "Blue binder", "Long box" ])
    end

    it "shows no place control to an account with a deck and no place (AC-5.8a)", :aggregate_failures do
      deck
      get scanner_path
      expect(html.at_css("#scanner_sitting select#sitting_location_id")).to be_nil
      expect(html.at_css("#scanner_sitting select#sitting_condition")).not_to be_nil
    end

    it "refuses a zone's id and a deck's id as the sitting's place, leaving the sitting's place alone (AC-5.2)", :aggregate_failures do
      place(blue.id)
      [ deck.zone("main").id, deck.location_id ].each do |id|
        place(id)
        expect(response).to have_http_status(:unprocessable_content), id.to_s
        expect(CGI.unescapeHTML(response.body)).to include("That location isn't one of yours any more. Choose again.")
        expect(html.at_css("select#sitting_location_id option[selected]").text).to eq("Blue binder")
      end
      expect(account.scanner_sitting.reload.location).to eq(blue)
    end

    it "keeps a lot that sits in a zone in its zone when an entry's Undo leaves part of it (AC-5.7)", :aggregate_failures do
      entry = add("a")
      zone = deck.zone("main")
      entry.lot.update!(location: zone, quantity: 3)
      undo(entry)
      expect(response).to have_http_status(:ok)
      expect(entry.lot.reload).to have_attributes(location: zone, quantity: 2)
      expect(entry.lot.lot_key).to end_with("|#{zone.id}")
    end
  end

  describe "the control and the panel (spec 042)" do
    def scale
      [ [ "Near mint (NM)", "near_mint" ], [ "Lightly played (LP)", "lightly_played" ], [ "Moderately played (MP)", "moderately_played" ],
        [ "Heavily played (HP)", "heavily_played" ], [ "Damaged (DMG)", "damaged" ] ]
    end

    def picker = html.at_css("#scanner_sitting form[action='#{scanner_sitting_path}']")
    def chosen(field) = picker.at_css("select#sitting_#{field} option[selected]").text
    def choose(**choices) = Scanner::Sitting.choose!(account:, **choices)
    def metas = html.css("#scanner_sitting > ul > li .c-list__meta").map { it.text.squish }

    it "shows the control alone before the first add: legend, Condition with Not specified first, Set, nothing of a sitting (AC-1.1, AC-3.1)", :aggregate_failures do
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
      expect(picker.at_css("fieldset legend").text).to eq("This sitting's cards")
      expect(picker.at_css("label[for=sitting_condition]").text).to eq("Condition")
      expect(picker.css("select#sitting_condition option").map { [ it.text, it["value"] ] }).to eq([ [ "Not specified", "" ], *scale ])
      expect(chosen(:condition)).to eq("Not specified")
      expect(picker.at_css("input[type=submit]")["value"]).to eq("Set")
      expect(picker.at_css("select#sitting_location_id")).to be_nil # no locations, so no Location select and no hint to /locations
      expect(html.at_css("#scanner_sitting a")).to be_nil
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "puts the Location select after Condition while the account has locations (AC-1.1)", :aggregate_failures do
      create(:location, account:, name: "Blue binder")
      get scanner_path
      expect(picker.css("select").map { it["id"] }).to eq(%w[sitting_condition sitting_location_id])
      expect(picker.at_css("label[for=sitting_location_id]").text).to eq("Location")
    end

    it "names the sitting's choices in the heading, in the order condition then place (decision 3, AC-3.2)", :aggregate_failures do
      blue = create(:location, account:, name: "Blue binder")
      choose(condition: "near_mint", location: blue)
      3.times { add(format("%x", it)) }
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Near mint, in Blue binder")
      expect([ chosen(:condition), chosen(:location_id) ]).to eq([ "Near mint (NM)", "Blue binder" ])
      choose(location: nil)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Near mint")
      choose(condition: nil, location: blue)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, in Blue binder")
    end

    it "says what cards go into in a sitting with no entries, naming only what is set (decision 3, AC-1.2)", :aggregate_failures do
      blue = create(:location, account:, name: "Blue binder")
      choose(condition: "near_mint", location: blue)
      get scanner_path
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint, in Blue binder.")
      choose(location: nil)
      get scanner_path
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint.")
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
      choose(condition: nil, location: blue)
      get scanner_path
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: in Blue binder.")
    end

    it "drops a sitting with no entries and neither choice when the scanner renders, and says the undone copy once every add was undone (AC-3.3, decision 3)", :aggregate_failures do
      Scanner::Sitting.create!(account:) # what a redraw with neither choice leaves ("Nothing added yet.") until the next render
      get scanner_path
      expect(Scanner::Sitting.count).to eq(0)
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(picker.at_css("select#sitting_condition")).not_to be_nil
      choose(condition: "near_mint")
      add("a").undo!
      get scanner_path
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Everything added in this sitting was undone.")
    end

    it "keeps a sitting that holds a condition and no entries (AC-3.3)", :aggregate_failures do
      choose(condition: "near_mint")
      get scanner_path
      expect(Scanner::Sitting.count).to eq(1)
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
    end

    it "keeps the condition on a reload (AC-1.7)" do
      choose(condition: "lightly_played")
      get scanner_path
      expect(chosen(:condition)).to eq("Lightly played (LP)")
    end

    it "shows the short label after the finish, from the entry's lot as it is now (decision 3, AC-2.3)", :aggregate_failures do
      blue = create(:location, account:, name: "Blue binder")
      plain = create(:mtg_printing, finishes: [], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry
      choose(condition: "near_mint")
      edited = add("a")
      unspecified = add("b", finish: "", card: plain)
      choose(condition: "near_mint", location: blue)
      gone = add("c", card: create(:mtg_printing, entry: create(:catalog_entry, name: "Shock", set: mom, number: "9")).entry)
      edited.lot.update!(condition: "lightly_played")
      gone.lot.destroy!
      get scanner_path
      expect(metas).to match([ /\AMOM · 9 · Foil · Added .+ ago\z/, /\AMOM · 7 · — · NM · Added .+ ago\z/, /\AMOM · 123 · Foil · LP · Added .+ ago\z/ ])
      expect(unspecified.lot.condition).to eq("near_mint")
      expect(html.css("#scanner_sitting > ul > li").first.text).to include("Changed in your collection")
    end

    # Passes before the change (an entry with no condition reads as today): kept as a regression guard.
    it "shows the entry with no condition when the sitting had none (AC-1.5)" do
      add("a")
      get scanner_path
      expect(metas).to match([ /\AMOM · 123 · Foil · Added .+ ago\z/ ])
    end

    it "shows the control on the summary after Done, on Not specified, for every account (AC-5.2)", :aggregate_failures do
      choose(condition: "near_mint")
      add("a")
      post scanner_sitting_ending_path
      follow_redirect!
      expect(html.at_css("#scanner_sitting").text.squish).to include("Added 1 card in this sitting")
      expect(chosen(:condition)).to eq("Not specified")
      expect(Scanner::Sitting.count).to eq(0)
    end

    # Passes before the change too (the entry line reads the vocabulary, not a query): kept as a regression guard for NFR cost.
    it "adds no query per entry to the page (NFR cost)", :aggregate_failures do
      choose(condition: "near_mint")
      2.times { add(format("%x", it), card: create(:mtg_printing, entry: create(:catalog_entry, set: mom)).entry) }
      get scanner_path # warm the caches that the first render fills
      few = count_queries { get scanner_path }
      6.times { add(format("%x", it + 2), card: create(:mtg_printing, entry: create(:catalog_entry, set: mom)).entry) }
      expect(count_queries { get scanner_path }).to eq(few)
    end
  end

  it "returns to the scanner from the copy's Edit copy page (AC-3.4)" do
    entry = add("a")
    patch lot_path(entry.lot_id, return_to: scanner_path), params: { lot: { quantity: "1", finish: "foil", condition: "near_mint", price_paid: "" } }
    expect(response).to redirect_to(scanner_path)
  end

  describe "setting the choices (spec 042)" do
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def set(**fields) = patch(scanner_sitting_path, params: { sitting: fields }, headers: stream)
    def chosen(field) = html.at_css("select#sitting_#{field} option[selected]").text
    # The status line in the stream's update of "status" (`#status` itself is in the layout, not in a stream body).
    def status_line = html.at_css("turbo-stream[target=status] .c-status__message").text.squish

    it "opens a sitting holding the condition, redrawing the panel, for an account with no locations (AC-1.2, AC-3.1)", :aggregate_failures do
      set(condition: "near_mint")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">')
      expect(response.body).not_to include('target="scanner_result"')
      expect(account.scanner_sitting).to have_attributes(condition: "near_mint", location: nil)
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
      expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint.")
      expect(status_line).to eq("Cards you scan now: Near mint.")
      expect(chosen(:condition)).to eq("Near mint (NM)")
    end

    it "says both choices in the status line for an account with locations, in every variant (decision 3)", :aggregate_failures do
      blue
      {
        { condition: "near_mint", location_id: blue.id } => "Cards you scan now: Near mint, in Blue binder.",
        { condition: "near_mint", location_id: "" } => "Cards you scan now: Near mint, no location.",
        { condition: "", location_id: blue.id } => "Cards you scan now: condition not specified, in Blue binder."
      }.each do |fields, line|
        set(**fields)
        expect(status_line).to eq(line), fields.inspect
      end
      add("a")
      set(condition: "", location_id: "")
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
      expect(account.scanner_sitting.entries.count).to eq(1)
    end

    it "says only the condition for an account with no locations, also when it is cleared with a card kept (decision 3)", :aggregate_failures do
      add("a")
      set(condition: "near_mint")
      set(condition: "")
      expect(status_line).to eq("Cards you scan now: condition not specified.")
    end

    it "changes the condition of an open sitting, keeping its count, entries and place, and the cards already added stay put (AC-2.1, AC-2.4)", :aggregate_failures do
      set(condition: "near_mint", location_id: blue.id)
      entries = %w[a b c].map { add(it) }
      set(condition: "lightly_played")
      expect(account.scanner_sitting.reload).to have_attributes(condition: "lightly_played", location: blue, entries:)
      expect(entries.map { it.lot.reload.condition }.uniq).to eq([ "near_mint" ])
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Lightly played, in Blue binder")
      set(location_id: create(:location, account:, name: "Long box").id)
      expect(account.scanner_sitting.reload).to have_attributes(condition: "lightly_played", location: Location.find_by!(name: "Long box"))
    end

    it "clears the condition of a sitting with a card and keeps it; deletes a sitting with no card, condition or place, and says what the next scan gets (AC-1.8, AC-4.2)", :aggregate_failures do
      set(condition: "near_mint")
      add("a")
      set(condition: "")
      expect(account.scanner_sitting.reload.condition).to be_nil
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 1 card")

      account.scanner_sitting.entries.sole.undo!
      set(condition: "near_mint")
      set(condition: "")
      expect(Scanner::Sitting.count).to eq(0)
      expect(response).to have_http_status(:ok)
      expect(chosen(:condition)).to eq("Not specified")
      expect(html.at_css("#scanner_sitting h2")).to be_nil
      expect(status_line).to eq("Cards you scan now: condition not specified.") # this account has no locations
    end

    it "says what the next scan gets when both choices are cleared with no sitting open (AC-4.2)", :aggregate_failures do
      blue
      set(condition: "", location_id: "")
      expect(Scanner::Sitting.count).to eq(0)
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
    end

    # Passes before the change (the old controller or model already behaves so): regression guard.
    it "takes a sitting that holds a place and no condition to Not specified, deleting it while empty (AC-1.8)" do
      set(location_id: blue.id)
      set(location_id: "")
      expect(Scanner::Sitting.count).to eq(0)
    end

    it "answers 400 to a request with neither key, changing nothing, and keeps the other choice when only one is sent (AC-4.2)", :aggregate_failures do
      set(condition: "near_mint", location_id: blue.id)
      patch scanner_sitting_path, params: { sitting: { other: "1" } }, headers: stream
      expect(response).to have_http_status(:bad_request)
      patch scanner_sitting_path, params: {}, headers: stream
      expect(response).to have_http_status(:bad_request)
      expect(account.scanner_sitting.reload).to have_attributes(condition: "near_mint", location: blue)
      set(condition: "damaged")
      expect(account.scanner_sitting.reload).to have_attributes(condition: "damaged", location: blue)
    end

    it "refuses a condition that is not a key of the scanner's vocabulary, changing nothing, not even a place sent with it (AC-4.1)", :aggregate_failures do
      set(condition: "near_mint", location_id: blue.id)
      long_box = create(:location, account:, name: "Long box")
      [ "Near mint", "Near mint (NM)", "NEAR_MINT", "near_mint ", "mint", "<b>x</b>" ].each do |value|
        set(condition: value, location_id: long_box.id)
        expect(response).to have_http_status(:unprocessable_content), value.inspect
        expect(CGI.unescapeHTML(response.body)).to include("That isn't a known condition. Choose again.")
        expect([ chosen(:condition), chosen(:location_id) ]).to eq([ "Near mint (NM)", "Blue binder" ])
      end
      expect(account.scanner_sitting.reload).to have_attributes(condition: "near_mint", location: blue)
    end

    it "refuses a bad condition with no sitting open, opening none (AC-4.1)", :aggregate_failures do
      set(condition: "mint")
      expect(response).to have_http_status(:unprocessable_content)
      expect(Scanner::Sitting.count).to eq(0)
    end

    it "shows the condition's message when both values are refused, changing nothing (decision 9)", :aggregate_failures do
      set(condition: "near_mint")
      set(condition: "mint", location_id: create(:location).id)
      expect(response).to have_http_status(:unprocessable_content)
      body = CGI.unescapeHTML(response.body)
      expect(body).to include("That isn't a known condition. Choose again.")
      expect(body).not_to include("That location isn't one of yours any more.")
      expect(account.scanner_sitting.reload.condition).to eq("near_mint")
    end

    it "keeps spec 040's message for a refused location, and changes nothing when the condition was good (decision 9)", :aggregate_failures do
      set(condition: "near_mint")
      set(condition: "damaged", location_id: create(:location).id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(CGI.unescapeHTML(response.body)).to include("That location isn't one of yours any more. Choose again.")
      expect(account.scanner_sitting.reload.condition).to eq("near_mint")
    end

    it "ignores a sitting id, an account id and another account's id (AC-4.3)", :aggregate_failures do
      other = create(:user).account
      theirs = Scanner::Sitting.choose!(account: other, condition: "damaged")
      set(condition: "near_mint", sitting_id: theirs.id, account_id: other.id, id: theirs.id)
      expect(theirs.reload.condition).to eq("damaged")
      expect(account.scanner_sitting.reload.condition).to eq("near_mint")
    end

    it "ignores a sitting id and an account id at the top level of the request too (AC-4.3)", :aggregate_failures do
      other = create(:user).account
      theirs = Scanner::Sitting.choose!(account: other, condition: "damaged")
      patch scanner_sitting_path, params: { sitting: { condition: "near_mint" }, sitting_id: theirs.id, account_id: other.id }, headers: stream
      expect(theirs.reload.condition).to eq("damaged")
      expect(account.scanner_sitting.reload.condition).to eq("near_mint")
    end

    it "ends the sitting with its condition, and the next one starts on Not specified (AC-5.1, AC-5.2)", :aggregate_failures do
      set(condition: "near_mint")
      add("a")
      post scanner_sitting_ending_path
      follow_redirect!
      expect(chosen(:condition)).to eq("Not specified")
      expect([ Scanner::Sitting.count, account.lots.sole.condition ]).to eq([ 0, "near_mint" ])
      set(condition: "damaged")
      expect(response.body).not_to include("in this sitting.")
      expect(Scanner::Sitting.sole.condition).to eq("damaged")
    end

    it "takes Undo of an entry added under another condition from the lot it went into (AC-2.2)", :aggregate_failures do
      set(condition: "near_mint")
      first = add("a")
      set(condition: "lightly_played")
      add("b")
      undo(first)
      expect(account.lots.map { [ it.condition, it.quantity ] }).to eq([ [ "lightly_played", 1 ] ])
      expect(chosen(:condition)).to eq("Lightly played (LP)")
    end

    # Passes before the change (the old controller or model already behaves so): regression guard.
    it "sends a signed-out visitor to sign in" do
      delete session_path
      set(condition: "near_mint")
      expect(response).to redirect_to(new_session_path)
    end

    # Passes before the change (the old controller or model already behaves so): regression guard.
    it "never touches another account's sitting (tenant isolation)", :aggregate_failures do
      other = create(:user).account
      theirs = Scanner::Sitting.choose!(account: other, condition: "damaged", location: create(:location, account: other))
      set(condition: "")
      expect(theirs.reload).to have_attributes(condition: "damaged")
      expect(account.scanner_sitting).to be_nil
    end
  end

  describe "after a redraw (spec 047)" do
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def set(**fields) = patch(scanner_sitting_path, params: { sitting: fields }, headers: stream)
    def status_line = html.at_css("turbo-stream[target=status] .c-status__message").text.squish
    # Where the redrawn panel says focus goes: nil when it names none.
    def focus_to = html.at_css("#scanner_sitting")["data-sitting-focus-to-value"]

    it "names the Set button after a Set that opens, changes, or clears a sitting (AC-1.1 to AC-1.4)", :aggregate_failures do
      blue
      set(condition: "near_mint")
      expect(focus_to).to eq("set")
      expect(html.at_css("#scanner_sitting")["data-controller"]).to eq("sitting-focus")
      expect(status_line).to eq("Cards you scan now: Near mint, no location.")
      set(condition: "")
      expect(Scanner::Sitting.count).to eq(0)
      expect(focus_to).to eq("set")
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
      set(condition: "", location_id: "")
      expect(focus_to).to eq("set")
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
    end

    it "names the Set button after a Set the server refuses, and keeps the alert (AC-1.5)", :aggregate_failures do
      set(condition: "mint-ish")
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("set")
      expect(html.at_css("turbo-stream[target=status] .c-status__message--alert").text.squish).to eq(Scanner::SittingsController::UNKNOWN_CONDITION)
    end

    it "names the Set button when the location is no longer the account's (AC-1.5)", :aggregate_failures do
      set(location_id: create(:location).id) # another account's location
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("set")
      expect(html.at_css("turbo-stream[target=status] .c-status__message--alert").text.squish).to eq(Scanner::SittingsController::GONE)
    end

    it "names the heading after an Undo, done or refused (AC-2.1, AC-2.3)", :aggregate_failures do
      entry = add("a")
      add("b")
      undo(entry)
      expect(focus_to).to eq("heading")
      expect(html.at_css("#scanner_sitting h2[tabindex='-1'][data-sitting-focus-target='heading']").text).to eq("This sitting: 1 card")
      expect(status_line).to start_with("Removed 1 × Lightning Bolt")
      undo(entry)
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("heading")
      expect(status_line).to eq("That card was already undone.")
    end

    it "names no target after an add, or on the page's own render (AC-3.1, AC-3.2)", :aggregate_failures do
      add("a")
      get scanner_path
      expect(html.at_css("#scanner_sitting")["data-sitting-focus-to-value"]).to be_nil
      expect(html.at_css("#scanner_sitting")["data-controller"]).to be_nil
      post scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: "foil", reading_key: "b" * 32 } }, headers: stream
      expect(response).to have_http_status(:ok)
      expect(focus_to).to be_nil
    end

    it "writes a sentence in #status after every redraw, one example each (AC-4.1)", :aggregate_failures do
      entry = add("a")
      undo(entry)
      expect(status_line).not_to be_blank
      post scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: "foil", reading_key: "a" * 32 } }, headers: stream
      expect(status_line).to eq("You added this card, then undid it. Scan it again to add it.") # a replayed add redraws the panel
      set(condition: "near_mint")
      expect(status_line).not_to be_blank
    end
  end
end
