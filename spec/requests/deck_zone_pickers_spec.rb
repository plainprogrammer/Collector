require "rails_helper"

# Spec 065 AC-7.1, AC-8.1, AC-8.5: a copy put into a zone by each picker is shown as "Deck › Zone" on the collection page, no
# picker names another account's place, deck or zone, and the export still writes the zone by deck and key. These examples are
# characterisation: they were written after the pickers, as regression proofs that cut across the surfaces each phase tested.
RSpec.describe "Deck zones in the pickers, across surfaces", type: :request do
  let(:user) { create(:user) }
  let!(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing).entry }

  before { sign_in_as(user) }

  def account = user.account
  def zone = deck.zone("main")
  def page_html = Nokogiri::HTML5(response.body)
  def stream = { "Accept" => "text/vnd.turbo-stream.html, text/html" }

  # Another account's box, deck and one of its zones, which no request of this account may name or reach.
  def rival_locations
    other = create(:user).account
    rival_deck = create(:deck, account: other, name: "Rival deck")
    { "box" => create(:location, account: other, name: "Rival box").id, "deck" => rival_deck.location_id, "zone" => rival_deck.zone("main").id }
  end

  def add_by_number(target, location)
    post collection_number_entry_lines_path,
      params: { type: "mtg", set: target.set.code, language: target.language,
                line: { number: target.number, quantity: "1", finish: "nonfoil", location:, line_key: SecureRandom.hex(16) } }
  end

  it "shows a copy put into a zone by the lot form, number entry and the scanner as Deck › Zone on the collection page (AC-7.1)", :aggregate_failures do
    post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", location_id: zone.id } }
    add_by_number(create(:mtg_printing).entry, zone.id)
    patch scanner_sitting_path, params: { sitting: { location_id: zone.id } }, headers: stream
    post scanner_sitting_entries_path, params: { entry: { printing: create(:mtg_printing).entry.external_key, finish: "nonfoil", reading_key: "a" * 32 } }, headers: stream
    expect(account.lots.pluck(:location_id)).to eq([ zone.id ] * 3)
    get collection_path(view: "table")
    expect(page_html.css("tbody .c-table__place-name").map { it.text.squish }).to eq([ "Izzet Tempo › Main" ] * 3)
    expect(page_html.css("tbody .c-table__sub").map(&:text).join).to include("Izzet Tempo › Main")
  end

  describe "tenancy (AC-8.1)" do
    let(:lot) { create(:lot, account:, entry:, location: create(:location, account:)) }

    # Edit many, then the bulk form's submission for Move to…: it records the lot's tick first (spec 006 FR-4).
    def select_lot
      post collection_selection_path
      patch collection_selection_path, params: { go: "move", q: "", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ lot.id ], ticked_ids: [ lot.id ] }
    end

    it "names none of another account's locations on any picker or the filter", :aggregate_failures do
      rival_locations
      select_lot
      [ new_catalog_entry_lot_path(entry), edit_lot_path(lot), new_lot_move_path(lot), collection_path, collection_path(view: "table"),
        new_collection_move_path, scanner_path,
        collection_number_entry_path(type: "mtg", set: entry.set.code, language: entry.language) ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(response.body).not_to include("Rival"), path
      end
    end

    it "refuses their ids on every write that names a location, changing nothing", :aggregate_failures do
      select_lot # a bulk move with no selection answers before it looks at the destination (spec 041 decision 6)
      rival_locations.each_value do |id|
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", location_id: id } }
        expect(response).to have_http_status(:not_found)
        post lot_move_path(lot), params: { move: { copies: "1", location_id: id } }
        expect(response).to have_http_status(:not_found)
        post collection_move_path, params: { to: id }
        expect(response).to have_http_status(:not_found)
        patch scanner_sitting_path, params: { sitting: { location_id: id } }, headers: stream
        expect(response).to have_http_status(:unprocessable_content)
        add_by_number(entry, id)
        expect(response.body).to include("That location isn&#39;t one of yours any more. Choose again.")
      end
      expect(account.lots.sole).to have_attributes(id: lot.id, location_id: lot.location_id, quantity: 1)
    end

    it "reads their ids as all locations in the filter, with 200 and nothing of theirs shown", :aggregate_failures do
      lot
      rival = rival_locations
      [ rival["box"].to_s, rival["zone"].to_s, "deck:#{rival['deck']}" ].each do |value|
        get collection_path(view: "table", location: value)
        expect(response).to have_http_status(:ok)
        expect(page_html.at_css("select[name=location] option[selected]").text).to eq("All locations")
        expect(response.body).not_to include("Rival")
      end
    end
  end

  it "keeps the export's locations to places and writes a lot in a zone by deck and key (AC-8.5)", :aggregate_failures do
    create(:lot, account:, entry:, location: zone)
    data = CollectionExport.new(account:, at: Time.current).to_h
    expect(data["locations"]).to eq([])
    expect(data["lots"].sole["location"]).to eq({ "deck" => "Izzet Tempo", "zone" => "main" })
  end
end
