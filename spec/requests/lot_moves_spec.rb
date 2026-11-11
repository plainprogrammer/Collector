require "rails_helper"

# Spec 032 Story 3: the Move copies page and its write.
RSpec.describe "Lot moves", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
  let(:label) { "Lightning Bolt (#{entry.set.code.upcase} · 146)" }

  def html = Nokogiri::HTML5(response.body)
  def blue = @blue ||= create(:location, account:, name: "Blue binder")
  def box = @box ||= create(:location, account:, name: "Long box")
  def lot = @lot ||= create(:lot, account:, entry:, quantity: 4, location: box)
  def move(copies:, to:, **context) = post(lot_move_path(lot, **context), params: { move: { copies:, location_id: to } })

  # Deletes the destination with SQL once, right after the statement that finds it by id (a lost race, AC-6.7).
  def lose_race(location)
    done = false
    writes = []
    subscriber = lambda do |*, payload|
      sql = payload[:sql]
      writes << sql if sql.match?(/\A(INSERT INTO|UPDATE) "lots"/)
      next if done || !sql.match?(/FROM "locations" WHERE "locations"\."account_id" = .* AND "locations"\."id" = /) # the find; the lot's preload has no account_id

      done = true
      Location.where(id: location.id).delete_all
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    writes
  end

  describe "routes" do
    it "puts the move under a lot", :aggregate_failures do
      expect(new_lot_move_path(1)).to eq("/lots/1/move/new")
      expect(lot_move_path(1)).to eq("/lots/1/move")
    end
  end

  context "when signed in" do
    before do
      sign_in_as(user)
      blue
      lot
    end

    it "opens a page titled for the lot, with Copies, To, Move and Cancel (AC-3.1)", :aggregate_failures do
      get new_lot_move_path(lot)
      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Move copies of #{label}")
      copies = html.at_css('input[name="move[copies]"]')
      expect([ copies["min"], copies["max"], copies["value"] ]).to eq(%w[1 4 4])
      expect(html.at_css('select[name="move[location_id]"]').css("option").map(&:text)).to eq([ "No location", "Blue binder" ])
      expect(html.at_css('input[type=submit]')["value"]).to eq("Move")
      expect(html.css("a").map(&:text)).to include("Cancel")
    end

    it "writes the lot's price in the account's currency (spec 038 AC-1.4)", :aggregate_failures do
      account.update!(currency: "EUR")
      lot.update!(price_paid_cents: 1250)
      get new_lot_move_path(lot)
      expect(html.at_css(".c-pagehead__stats").text).to include("€12.50")
      expect(html.at_css(".c-pagehead__stats").text).not_to include("$")
    end

    it "starts an unplaced lot's select on the first location (AC-3.1)" do
      lot.update!(location: nil)
      get new_lot_move_path(lot)
      expect(html.at_css('select[name="move[location_id]"]').css("option").map(&:text)).to eq([ "Blue binder", "Long box" ])
    end

    it "moves the copies and says so (AC-3.2, AC-3.3, AC-3.5)", :aggregate_failures do
      move(copies: "4", to: blue.id)
      expect(response).to have_http_status(:see_other).and redirect_to(catalog_entry_path(entry))
      follow_redirect!
      expect(response.body).to include("Moved 4 × #{label} to Blue binder.")
      expect(account.lots.sole.location).to eq(blue)
      lot2 = create(:lot, account:, entry:, quantity: 5, finish: "foil", location: box)
      post lot_move_path(lot2), params: { move: { copies: "2", location_id: "" } }
      follow_redirect!
      expect(response.body).to include("Moved 2 × #{label} to no location.")
      expect(account.lots.where(finish: "foil").pluck(:location_id, :quantity)).to contain_exactly([ box.id, 3 ], [ nil, 2 ])
    end

    it "keeps the collection context in the redirect" do
      move(copies: "1", to: blue.id, from: "collection")
      expect(response).to redirect_to(catalog_entry_path(entry, from: "collection"))
    end

    it "answers 422 with the reasons beside Copies and To, keeping the choice (AC-3.6, AC-3.7)", :aggregate_failures do
      move(copies: "9", to: blue.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(html.at_css("#move_copies-error").text).to eq("Choose from 1 to 4 copies.")
      expect(html.css(".field_with_errors")).to be_empty
      expect(html.at_css('select[name="move[location_id]"] option[selected]').text).to eq("Blue binder")
      create(:lot, account:, entry:, location: blue, quantity: 9_998)
      move(copies: "2", to: blue.id)
      expect(html.at_css("#move_copies-error").text).to eq(Lot::FULL_MESSAGE)
      expect(html.css(".field_with_errors")).to be_empty
      expect(lot.reload.quantity).to eq(4)
    end

    it "refuses a move to where the lot already is (P4)", :aggregate_failures do
      move(copies: "1", to: box.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(html.at_css("#move_location_id-error").text).to eq("Those copies are already there.")
      expect(html.css(".field_with_errors")).to be_empty
    end

    it "answers 404 for another account's lot or destination, or a missing one, changing nothing (AC-3.9, AC-6.1, AC-6.2)", :aggregate_failures do
      other = create(:user).account
      theirs = create(:location, account: other, name: "Box")
      their_lot = create(:lot, account: other, entry:, location: theirs)
      get new_lot_move_path(their_lot)
      expect(response).to have_http_status(:not_found)
      post lot_move_path(their_lot), params: { move: { copies: "1", location_id: "" } }
      expect(response).to have_http_status(:not_found)
      [ theirs.id, 0, "x" ].each do |bad|
        move(copies: "1", to: bad)
        expect(response).to have_http_status(:not_found)
      end
      expect(lot.reload).to have_attributes(quantity: 4, location: box)
      expect(their_lot.reload.location).to eq(theirs)
    end

    it "says there are no locations and offers no Move when there are none (AC-3.10, P3)", :aggregate_failures do
      Lot.delete_all
      Location.delete_all
      unplaced = create(:lot, account:, entry:, quantity: 2)
      get new_lot_move_path(unplaced)
      expect(html.at_css("main").text).to include("You have no locations yet.")
      expect(html.css("input[type=submit], button").map { |control| control["value"].to_s + control.text }.grep(/Move/)).to be_empty
      expect(html.at_css("main a[href='#{locations_path}']")).to be_present
    end

    it "answers 404, not 500, when the destination is removed after it was found (AC-6.7)", :aggregate_failures do
      writes = lose_race(blue) { move(copies: "4", to: blue.id) }
      expect(response).to have_http_status(:not_found)
      expect(writes).not_to be_empty
      expect(lot.reload.location).to eq(box)
    end

    it "offers Move copies in the card page's lot menu, not in the collection table's (AC-3.1)", :aggregate_failures do
      get catalog_entry_path(entry)
      items = html.css("#copies .c-menu__item").map(&:text)
      expect(items).to eq([ "Edit copy", "Move copies", "Remove" ])
      get collection_path(view: "table")
      expect(response.body).not_to include("Move copies")
    end
  end

  # Spec 065 Story 2 (supersedes spec 062 AC-5.1, AC-5.2): a zone is a destination and a deck's own row is not; spec 062 AC-5.6: a
  # lot in a zone moves out as any lot does.
  context "with a deck (spec 062)" do
    def binder = @binder ||= create(:location, account:, name: "Binder")
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
    def zone = deck.zone("main")
    def zone_lot = @zone_lot ||= create_lot_in_zone(deck, "main", entry:, quantity: 4)

    before do
      sign_in_as(user)
      box
      binder
      deck
    end

    it "offers No location, Places and Decks to a lot in a place, its own place left out (spec 065 AC-2.1)", :aggregate_failures do
      get new_lot_move_path(create(:lot, account:, entry:, location: box))
      select = html.at_css('select[name="move[location_id]"]')
      expect(select.xpath("./option").map(&:text)).to eq([ "No location" ])
      expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
      expect(select.css('optgroup[label="Places"] option').map(&:text)).to eq([ "Binder" ])
      expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
    end

    it "offers No location, Places and Decks, the lot's own zone left out (spec 065 AC-2.1)", :aggregate_failures do
      get new_lot_move_path(zone_lot)
      expect(response).to have_http_status(:ok)
      select = html.at_css('select[name="move[location_id]"]')
      expect(select.xpath("./option").map(&:text)).to eq([ "No location" ])
      expect(select.css('optgroup[label="Places"] option').map(&:text)).to eq([ "Binder", "Long box" ])
      expect(select.css('optgroup[label="Decks"] option').map(&:text)).not_to include("Izzet Tempo › Main")
      expect(select.css('optgroup[label="Decks"] option').map(&:text)).to include("Izzet Tempo › Sideboard")
      expect(html.at_css(".c-pagehead__stats").text).to include("Izzet Tempo › Main") # the label, never the zone's name alone (AC-5.4)
    end

    it "moves some copies into a zone, merging as for a place, and names the label (spec 065 AC-2.2)", :aggregate_failures do
      post lot_move_path(lot), params: { move: { copies: "2", location_id: zone.id } }
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to end_with("to Izzet Tempo › Main.")
      expect(account.lots.where(location: zone).sum(:quantity)).to eq(2)
      expect(lot.reload.quantity).to eq(2)
    end

    it "refuses a lot's own zone and 404s a deck's own id, another account's zone and text that only starts with an id (spec 065 AC-2.3, AC-2.4)", :aggregate_failures do
      post lot_move_path(zone_lot), params: { move: { copies: "1", location_id: zone.id } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Those copies are already there.")
      foreign = create(:deck, account: create(:user).account)
      [ deck.location_id, foreign.zone("main").id, "#{binder.id}abc" ].each do |id|
        post lot_move_path(zone_lot), params: { move: { copies: "1", location_id: id } }
        expect(response).to have_http_status(:not_found), id.to_s
      end
      expect(zone_lot.reload.attributes.values_at("location_id", "quantity")).to eq([ zone.id, 4 ])
    end

    it "moves some copies of a lot in a zone to a place, merging into an equal lot there (AC-5.6)", :aggregate_failures do
      twin = create(:lot, account:, entry:, quantity: 1, location: binder)
      post lot_move_path(zone_lot), params: { move: { copies: "2", location_id: binder.id } }
      expect(response).to have_http_status(:see_other)
      expect(twin.reload.quantity).to eq(3)
      expect(zone_lot.reload.attributes.values_at("location_id", "quantity")).to eq([ zone.id, 2 ])
    end

    it "moves every copy of a lot in a zone to No location (AC-5.6)", :aggregate_failures do
      post lot_move_path(zone_lot), params: { move: { copies: "4", location_id: "" } }
      expect(response).to have_http_status(:see_other)
      expect(zone_lot.reload.attributes.values_at("location_id", "quantity")).to eq([ nil, 4 ])
    end
  end

  context "when signed out" do
    it "sends the page and the write to sign in (AC-6.5)", :aggregate_failures do
      other = create(:lot, entry:)
      get new_lot_move_path(other)
      expect(response).to redirect_to(new_session_path)
      post lot_move_path(other), params: { move: { copies: "1", location_id: "" } }
      expect(response).to redirect_to(new_session_path)
    end
  end
end
