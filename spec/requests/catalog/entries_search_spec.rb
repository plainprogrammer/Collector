require "rails_helper"

RSpec.describe "Card search", type: :request do
  def printing(name, identity: create(:catalog_identity, name:), **attributes)
    create(:catalog_entry, identity:, name:, **attributes)
  end

  def search(**params) = get(catalog_entries_path(params))

  it "finds cards by part of the name, ignoring case", :aggregate_failures do
    printing("Lightning Bolt")
    printing("Lightning Helix")

    search(q: "LIGHTNING bo")

    expect(response.body).to include("Lightning Bolt")
    expect(response.body).not_to include("Lightning Helix")
  end

  it "finds a card by a localized name and lists its other printings", :aggregate_failures do
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    en = printing("Lightning Bolt", identity: bolt)
    ja = printing("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻")

    search(q: "稲妻")

    expect(response.body).to include("Lightning Bolt", "稲妻", catalog_entry_path(en), catalog_entry_path(ja))
  end

  it "shows image, set, number, language, rarity and finishes for each printing", :aggregate_failures do
    set = create(:catalog_set, code: "m10", name: "Magic 2010")
    entry = printing("Lightning Bolt", set:, number: "146",
      image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")
    create(:mtg_printing, entry:, rarity: "common", finishes: %w[foil nonfoil])

    search(q: "bolt")

    expect(response.body).to include('src="https://cards.scryfall.io/normal/front/a/b/bolt.jpg"',
      "Magic 2010", "M10", "#146", "en", "Common", "foil, nonfoil")
  end

  it "does not render images from hosts outside the allowlist" do
    printing("Lightning Bolt", image_url: "https://evil.example/bolt.jpg")

    search(q: "bolt")

    expect(response.body).not_to include("evil.example")
  end

  it "links to all printings when a card has more than 10", :aggregate_failures do
    forest = create(:catalog_identity, name: "Forest")
    11.times { printing("Forest", identity: forest) }

    search(q: "forest")

    expect(response.body.scan(%r{href="/catalog/entries/}).size).to eq(10)
    expect(response.body).to include("Show all 11 printings", catalog_identity_path(forest))
  end

  it "pages 12 cards at a time", :aggregate_failures do
    13.times { |i| printing(format("Card %02d", i)) }

    search(q: "card")
    expect(response.body).to include("Card 11", 'rel="next"')
    expect(response.body).not_to include("Card 12")

    search(q: "card", page: 2)
    expect(response.body).to include("Card 12", 'rel="prev"')
  end

  it "falls back to the first or last page for invalid page numbers", :aggregate_failures do
    13.times { |i| printing(format("Card %02d", i)) }

    search(q: "card", page: "abc")
    expect(response.body).to include("Page 1 of 2")

    search(q: "card", page: 99)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Page 2 of 2")
  end

  it "says no cards were found", :aggregate_failures do
    search(q: "nothing matches")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No cards found")
  end

  it "prompts for a name when the query is blank or whitespace" do
    search(q: "   ")

    expect(response.body).to include("Enter a card name")
  end

  it "treats wildcard characters literally" do
    printing("Fires of Yavimaya")

    search(q: "Fire_")

    expect(response.body).to include("No cards found")
  end

  it "hides tokens, emblems, art cards and retired printings", :aggregate_failures do
    printing("Goblin Token", kind: "token")
    printing("Ajani Emblem", kind: "emblem")
    printing("Goblin Art", kind: "art_card")
    printing("Goblin Retired", retired_at: 1.day.ago)

    search(q: "goblin")

    expect(response.body).to include("No cards found")
  end

  it "narrows a card's printings to the selected set", :aggregate_failures do
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    a = printing("Lightning Bolt", identity: bolt, set: create(:catalog_set, code: "aaa"))
    b = printing("Lightning Bolt", identity: bolt, set: create(:catalog_set, code: "bbb"))

    search(q: "bolt", set: "aaa")

    expect(response.body).to include(catalog_entry_path(a))
    expect(response.body).not_to include(catalog_entry_path(b))
  end

  it "lists every searchable card in a set when only a set is chosen" do
    set = create(:catalog_set, code: "aaa")
    printing("Alpha", set:)
    printing("Beta", set:)

    search(set: "aaa")

    expect(response.body).to include("Alpha", "Beta")
  end

  it "offers sets with searchable printings, newest first", :aggregate_failures do
    printing("Old", set: create(:catalog_set, code: "old", released_on: Date.new(1993, 1, 1)))
    printing("New", set: create(:catalog_set, code: "new", released_on: Date.new(2024, 1, 1)))
    printing("Token", kind: "token", set: create(:catalog_set, code: "tkn"))

    search

    expect(response.body.index('value="new"')).to be < response.body.index('value="old"')
    expect(response.body).not_to include('value="tkn"')
  end

  it "returns no results for an unknown set code", :aggregate_failures do
    printing("Lightning Bolt")

    search(q: "bolt", set: "nope")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No cards found")
  end

  it "says the catalog has not been loaded until a refresh has applied" do
    create(:catalog_refresh_run, status: "failed")

    search

    expect(response.body).to include("has not been loaded yet")
  end

  it "shows the date of the last applied refresh" do
    create(:catalog_refresh_run, finished_at: Time.zone.local(2026, 9, 28, 3, 20))

    search

    expect(response.body).to include("September 28, 2026")
  end

  it "makes no outbound requests while rendering" do
    printing("Lightning Bolt", image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")

    search(q: "bolt")

    expect(a_request(:any, /.*/)).not_to have_been_made
  end
end
