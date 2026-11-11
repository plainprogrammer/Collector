require "rails_helper"

# Spec 065 Story 6: the collection's Location select offers zones and "<Deck> (all zones)", and filters by them.
RSpec.describe "The collection's location filter with decks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    [ in_main, in_side, in_box, loose ] # the account's four lots, made before each example
  end

  def account = user.account
  def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
  def box = @box ||= create(:location, account:, name: "Long box")
  def in_main = @in_main ||= owned_printing("Lightning Bolt", account:, number: "146", location: deck.zone("main"))
  def in_side = @in_side ||= owned_printing("Counterspell", account:, number: "50", location: deck.zone("sideboard"))
  def in_box = @in_box ||= owned_printing("Opt", account:, number: "60", location: box)
  def loose = @loose ||= owned_printing("Shock", account:, number: "70")
  def page_html = Nokogiri::HTML5(response.body)
  def select = page_html.at_css('select[name="location"]')
  def names = page_html.css(".c-tile__name").map { it.text.squish } # the grid is the default view
  def deck_value = CollectionFilter::Place.deck_value(deck.location_id)

  it "lists All locations and No location, then Places, then Decks with each deck's all-zones option first (AC-6.1)", :aggregate_failures do
    get collection_path
    expect(select.xpath("./option").map(&:text)).to eq([ "All locations", "No location" ])
    expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
    expect(select.css('optgroup[label="Places"] option').map(&:text)).to eq([ "Long box" ])
    expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq([ "Izzet Tempo (all zones)", *deck.zones.map { "Izzet Tempo › #{it.name}" } ])
    expect(select.css('optgroup[label="Decks"] option').first["value"]).to eq(deck_value)
  end

  it "is flat with no deck (AC-6.1)", :aggregate_failures do
    account.lots.where(location: deck.zones).destroy_all
    deck.remove!
    get collection_path
    expect(select.css("optgroup")).to be_empty
    expect(select.css("option").map(&:text)).to eq([ "All locations", "No location", "Long box" ])
  end

  it "narrows to one zone: its lots, quantities and count, no place line (AC-6.2)", :aggregate_failures do
    get collection_path(location: deck.zone("main").id)
    expect(names).to eq([ "Lightning Bolt" ])
    expect(page_html.css(".c-tile__place-name")).to be_empty
    expect(response.body).to include("1 of 4 items")
    expect(select.at_css("option[selected]").text).to eq("Izzet Tempo › Main")
  end

  it "narrows to every zone of a deck, tiles with no place line, rows with each zone (AC-6.3)", :aggregate_failures do
    get collection_path(location: deck_value)
    expect(names).to contain_exactly("Lightning Bolt", "Counterspell")
    expect(page_html.css(".c-tile__place-name")).to be_empty
    get collection_path(location: deck_value, view: "table")
    expect(page_html.css("tbody .c-table__place-name").map { it.text.squish }).to contain_exactly("Izzet Tempo › Main", "Izzet Tempo › Sideboard")
    expect(select.at_css("option[selected]").text).to eq("Izzet Tempo (all zones)")
  end

  it "says so when a zone or a deck holds nothing (AC-6.4)", :aggregate_failures do
    get collection_path(location: deck.zone("considering").id)
    expect(response.body).to include("No cards in your collection are in “Izzet Tempo › Considering”.")
    in_side.destroy!
    in_main.destroy!
    get collection_path(location: deck_value)
    expect(response.body).to include("No cards in your collection are in “Izzet Tempo”.")
    get collection_path(location: deck_value, q: "zzz")
    expect(response.body).to include('No cards in your collection match "zzz" in “Izzet Tempo”.')
  end

  it "reads anything it can't resolve as all, naming nothing of another account (AC-6.5, AC-8.1)", :aggregate_failures do
    foreign = create(:deck, account: create(:user).account, name: "Secret deck")
    values = [ foreign.zone("main").id.to_s, "deck:#{foreign.location_id}", deck.location_id.to_s, "deck:#{deck.zone('main').id}",
               "deck:99999", "deck:", "deck:0#{deck.location_id}", "012", "x" ]
    values.each do |value|
      get collection_path(location: value)
      expect(response).to have_http_status(:ok), value
      expect(select.at_css("option[selected]")&.text || "All locations").to eq("All locations"), value
      expect(names.size).to eq(4), value
      expect(response.body).not_to include("Secret deck")
    end
  end

  it "keeps the filter through the view switch, a sort header and Edit many, and doesn't save it (AC-6.6)", :aggregate_failures do
    get collection_path(location: deck_value, view: "table")
    carried = page_html.css("a, form, input").flat_map { [ it["href"], it["action"], it["value"] ] }.compact.join(" ")
    expect(carried).to include("deck%3A#{deck.location_id}").or include("deck:#{deck.location_id}")
    expect(page_html.at_css("#edit-many input[name=location]")["value"]).to eq(deck_value)
    get collection_path
    expect(select.at_css("option[selected]")&.text || "All locations").to eq("All locations")
  end

  it "gives an account with a deck and no place the select, the column and the place line (AC-6.10)", :aggregate_failures do
    solo = create(:user)
    delete session_path # the example's own account, not the one signed in above
    sign_in_as(solo)
    create(:deck, account: solo.account)
    owned_printing("Opt", account: solo.account, number: "60")
    get collection_path
    expect(select).not_to be_nil
    expect(page_html.css(".c-tile__place-name").map { it.text.squish }).to eq([ "No location" ])
    get collection_path(view: "table")
    expect(page_html.css("thead th").map { it.text.squish }).to include("Location")
  end

  it "escapes a deck's name in the options and sentences (AC-6.9)", :aggregate_failures do
    odd = create(:deck, account:, name: "A <i>&\" deck")
    get collection_path(location: CollectionFilter::Place.deck_value(odd.location_id))
    expect(response.body).not_to include("<i>")
    expect(response.body).to include("A &lt;i&gt;&amp;&quot; deck")
  end

  # Bulk mode keeps the value it was made under (spec 037 decision 7) and acts on the lots that value matches.
  describe "bulk mode under a zone or a deck (AC-6.7, AC-6.8, AC-6.11)" do
    def select_under(filter, *lots, go:)
      post collection_selection_path, params: { location: filter }
      patch collection_selection_path, params: { go:, q: "", rendered_q: "", rendered_location: filter, all_rendered: "0",
        shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
    end

    it "sets a condition on exactly the deck's lots; a lot outside it whose id is sent is ignored", :aggregate_failures do
      lots = [ in_main, in_side ]
      outsider = in_box
      select_under(deck_value, *lots, outsider, go: "set_condition")
      post collection_condition_change_path, params: { condition: "lightly_played" }
      expect(lots.map { it.reload.condition }).to eq(%w[lightly_played lightly_played])
      expect(outsider.reload.condition).not_to eq("lightly_played")
    end

    it "restarts the selection empty after a move to another zone of the same deck (decision 12)", :aggregate_failures do
      lot = in_main
      select_under(deck_value, lot, go: "move")
      post collection_move_path, params: { to: deck.zone("sideboard").id }
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Moved 1 item to Izzet Tempo › Sideboard.")
      expect(lot.reload.location).to eq(deck.zone("sideboard"))
      follow_redirect!
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
    end

    it "offers every zone of the deck as a destination under a deck filter, leaving out none (AC-3.1)", :aggregate_failures do
      select_under(deck_value, in_main, go: "move")
      get new_collection_move_path
      expect(page_html.css('select#to optgroup[label="Decks"] option').map(&:text)).to include("Izzet Tempo › Main", "Izzet Tempo › Sideboard")
    end

    it "moves lots selected under a deck's value to a place (AC-3.4)", :aggregate_failures do
      lots = [ in_main, in_side ]
      select_under(deck_value, *lots, go: "move")
      post collection_move_path, params: { to: box.id }
      expect(response).to have_http_status(:see_other)
      expect(lots.map { it.reload.location }).to all(eq(box))
      expect(BulkSelection.find_by(session: user.sessions.last)).to have_attributes(location_filter: deck_value, marks: be_empty)
    end

    it "removes exactly the deck's lots when every matching lot is selected (AC-6.7)", :aggregate_failures do
      post collection_selection_path, params: { location: deck_value }
      # The header's "select every matching lot" (spec 006 FR-4): the marks are exceptions, so the filter alone decides.
      patch collection_selection_path, params: { go: "remove", q: "", rendered_q: "", rendered_location: deck_value, all_rendered: "1", all: "1",
        header_toggled: "1", shown_ids: [ in_main.id, in_side.id ] }
      post collection_bulk_removals_path
      expect(account.lots.pluck(:id)).to contain_exactly(in_box.id, loose.id)
    end

    it "shows nothing selected when the value changes between the page and the action (AC-6.7)", :aggregate_failures do
      select_under(deck_value, in_main, go: "move")
      get collection_path(bulk: 1, location: deck.zone("main").id)
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
    end

    it "acts on nothing under a deck that was removed in another tab (AC-6.8)", :aggregate_failures do
      ghost = create(:deck, account:, name: "Ghost")
      ghost_value = CollectionFilter::Place.deck_value(ghost.location_id)
      post collection_selection_path, params: { location: ghost_value } # the selection is made under the ghost deck's value
      ghost.remove!                                                    # then the deck goes in another tab
      patch collection_selection_path, params: { go: "remove", q: "", rendered_q: "", rendered_location: ghost_value, all_rendered: "1", all: "1", header_toggled: "1" }
      expect(response.body).to include("None of the selected items are in your collection any more.")
      expect(account.lots.count).to eq(4)
    end
  end
end
