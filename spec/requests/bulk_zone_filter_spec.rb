require "rails_helper"

# Spec 062 D6, AC-5.2, AC-5.7, AC-5.7a, AC-5.7b and spec 037 decision 7 (not superseded): a stored bulk selection keeps the location
# string it was made under and never re-resolves it, so a request can store a zone's id or a deck's id there even though the page
# only offers places. These examples pin what each bulk path does then: it acts on the account's own lots in that zone (a deck's
# own row holds none), keeps a lot in its zone unless the collector moves it, and never unplaces one by accident.
RSpec.describe "A bulk selection stored under a zone's or a deck's id", type: :request do
  let(:user) { create(:user) }
  let!(:box) { create(:location, account:, name: "Long box") }
  let!(:zoned) { create_lot_in_zone(deck, "main", entry: create(:mtg_printing).entry, quantity: 2) }
  let!(:placed) { create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 3, location: box) }

  before { sign_in_as(user) }

  def account = user.account
  def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
  def zone = deck.zone("main")
  def page_html = Nokogiri::HTML5(response.body)

  # What a crafted submission of the bulk form does: it starts a selection under +filter+ and ticks the lots.
  def select_under(filter, *lots, go:)
    post collection_selection_path, params: { location: filter }
    patch collection_selection_path, params: { go:, q: "", rendered_q: "", rendered_location: filter, all_rendered: "0",
      shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
  end

  it "shows the page as for all locations, with nothing selected, when the filter is not a place (spec 037 decision 7)", :aggregate_failures do
    [ zone.id, deck.location_id ].each do |id|
      post collection_selection_path, params: { location: id }
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(page_html.at_css("input[name=rendered_location]")["value"]).to eq("")
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
      expect(page_html.css("tbody tr").size).to eq(2)
    end
  end

  it "sets a condition on the zone's lots only, each staying in its zone", :aggregate_failures do
    select_under(zone.id.to_s, zoned, placed, go: "set_condition")
    expect(response).to redirect_to(new_collection_condition_change_path)
    post collection_condition_change_path, params: { condition: "lightly_played" }
    expect(zoned.reload).to have_attributes(condition: "lightly_played", location: zone)
    expect(zoned.lot_key).to eq(Lot.key_for(nil, "lightly_played", nil, zone.id))
    expect(placed.reload).to have_attributes(condition: nil, location: box)
  end

  it "selects nothing under a deck's id, so no bulk path changes a lot", :aggregate_failures do
    %w[set_condition move remove].each do |go|
      select_under(deck.location_id.to_s, zoned, placed, go:)
      expect(response).to have_http_status(:unprocessable_content)
    end
    post collection_condition_change_path, params: { condition: "damaged" }
    post collection_move_path, params: { to: box.id }
    post collection_bulk_removals_path
    expect(Lot.pluck(:id, :condition, :location_id, :quantity)).to contain_exactly([ zoned.id, nil, zone.id, 2 ], [ placed.id, nil, box.id, 3 ])
  end

  it "moves the zone's lots to the place the collector chooses, as Move to… does for any lot", :aggregate_failures do
    select_under(zone.id.to_s, zoned, placed, go: "move")
    post collection_move_path, params: { to: zone.id }
    expect(response).to have_http_status(:not_found)
    expect(zoned.reload.location).to eq(zone)
    post collection_move_path, params: { to: box.id }
    expect(zoned.reload).to have_attributes(location: box, lot_key: Lot.key_for(nil, nil, nil, box.id))
    expect(placed.reload.location).to eq(box)
  end

  it "removes the zone's lots, and Undo puts them back in the zone", :aggregate_failures do
    select_under(zone.id.to_s, zoned, placed, go: "remove")
    post collection_bulk_removals_path
    expect(Lot.pluck(:id)).to eq([ placed.id ])
    follow_redirect!
    post page_html.at_css(".c-status form.c-status__action")["action"], params: { return_to: collection_path(bulk: 1) }
    expect(account.lots.where(location_id: zone.id).sole).to have_attributes(quantity: 2, lot_key: Lot.key_for(nil, nil, nil, zone.id))
  end
end
