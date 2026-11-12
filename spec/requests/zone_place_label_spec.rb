require "rails_helper"

# Spec 062 AC-5.4, AC-5.7b, decision 6: a lot in a deck's zone is shown as "Deck › Zone" wherever a place is shown, never as the
# zone's name alone ("Main" says nothing about which deck).
RSpec.describe "A zone shown as a place", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let!(:zone_lot) { owned_printing("Lightning Bolt", account:, number: "146", location: deck.zone("main")) }

  before { sign_in_as(user) }

  def label = "Izzet Tempo › Main"
  def entry = zone_lot.entry
  def page_html = Nokogiri::HTML5(response.body)

  # The page's source with every label taken out (and the navigation landmarks, which are named "Main"): a "Main" left over names
  # the zone without its deck.
  def without_label = response.body.gsub(label, "").gsub('aria-label="Main"', "")

  it "reads the label on the card page's copies row, its phone line and its menu's name", :aggregate_failures do
    get catalog_entry_path(entry)
    row = page_html.at_css("#copies tbody tr")
    expect(row.css("td.is-opt").map { it.text.squish }).to include(label)
    expect(row.at_css(".c-table__sub").text).to include(label)
    expect(row.at_css("summary")["aria-label"]).to end_with(" in #{label}")
    # "In decks" names the zone in its own Zone column on the deck's row, next to the deck's link (spec 073 decision 4), so it is
    # never the zone's name alone (spec 062 decision 6); the check is on the rest of the page.
    expect(without_label.sub(%r{<section id="in-decks">.*?</section>}m, "")).not_to include("Main")
  end

  it "orders a deck's zones together under the deck's name on the card page", :aggregate_failures do
    beta = create(:deck, account:, name: "Beta deck")
    create_lot_in_zone(beta, "sideboard", entry:)
    create_lot_in_zone(beta, "main", entry:)
    create(:lot, account:, entry:, location: create(:location, account:, name: "Alpha box"))
    create(:lot, account:, entry:, location: create(:location, account:, name: "Zed box"))
    create(:lot, account:, entry:)
    get catalog_entry_path(entry)
    cells = page_html.css("#copies tbody tr td:nth-child(5)").map { it.text.squish }
    expect(cells).to eq([ "No location", "Alpha box", "Beta deck › Main", "Beta deck › Sideboard", label, "Zed box" ])
  end

  it "reads the label in the table's Location cell and phone line", :aggregate_failures do
    get collection_path(view: "table")
    row = page_html.at_css("tbody tr")
    expect(row.at_css(".c-table__place-name").text).to eq(label)
    expect(row.at_css(".c-table__sub").text).to include(label)
    expect(without_label).not_to include("Main")
  end

  it "reads the label on the grid tile's place line", :aggregate_failures do
    get collection_path
    expect(page_html.at_css(".c-tile__place-name").text).to eq(label)
    expect(without_label).not_to include("Main")
  end

  it "reads the label in bulk mode's place cell and line", :aggregate_failures do
    post collection_selection_path
    get collection_path(bulk: 1)
    row = page_html.at_css("tbody tr")
    expect(row.at_css(".c-table__place-name").text).to eq(label)
    expect(row.at_css(".c-table__sub").text).to include(label)
    expect(without_label).not_to include("Main")
  end

  it "keeps each zone lot in its zone under bulk Set condition (AC-5.7b)", :aggregate_failures do
    other = create_lot_in_zone(deck, "sideboard", entry:)
    post collection_selection_path
    patch collection_selection_path, params: { go: "set_condition", q: "", rendered_q: "", all_rendered: "0", shown_ids: [ zone_lot.id, other.id ], ticked_ids: [ zone_lot.id, other.id ] }
    post collection_condition_change_path, params: { condition: "lightly_played" }
    expect(zone_lot.reload.location).to eq(deck.zone("main"))
    expect(other.reload.location).to eq(deck.zone("sideboard"))
    expect([ zone_lot.condition, other.condition ]).to eq(%w[lightly_played lightly_played])
  end

  it "reads the label on the deck's refusal page", :aggregate_failures do
    get new_deck_removal_path(deck)
    expect(page_html.at_css(".c-decks__zone").text).to eq(label)
    expect(without_label).not_to include("Main")
  end

  it "reads the label in number entry's list and its Undo's name", :aggregate_failures do
    list = NumberEntry.create!(account:)
    line = list.lines.create!(account:, entry:, lot: zone_lot, quantity: 1, finish: nil, line_key: SecureRandom.hex(16))
    get collection_number_entry_path(type: "mtg", set: entry.set.code, language: entry.language)
    expect(response).to have_http_status(:ok)
    item = page_html.css("li").find { it.text.include?(line.entry.name) }
    expect(item.at_css(".c-list__meta").text).to include("in #{label}")
    expect(item.at_css("button[aria-label]")["aria-label"]).to end_with(" in #{label}")
    expect(without_label).not_to include("Main")
  end

  it "reads the label in the scanner sitting's entries", :aggregate_failures do
    sitting = Scanner::Sitting.create!(account:)
    sitting.entries.create!(account:, printing: entry, lot: zone_lot, finish: nil, reading_key: SecureRandom.hex(16))
    get scanner_path
    expect(page_html.css("#sitting li .c-list__meta, .c-scanner__sitting li .c-list__meta").map(&:text).join).to include("in #{label}")
    expect(without_label).not_to include("Main")
  end
end
