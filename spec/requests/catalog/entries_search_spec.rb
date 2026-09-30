require "rails_helper"

RSpec.describe "Card search", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

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

  it "shows each printing as a tile with image, name, set · number and language", :aggregate_failures do
    set = create(:catalog_set, code: "m10", name: "Magic 2010")
    entry = printing("Lightning Bolt", set:, number: "146", image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")
    create(:mtg_printing, entry:)

    search(q: "bolt")

    expect(response.body).to include('src="https://cards.scryfall.io/normal/front/a/b/bolt.jpg"', "M10 · 146", ">EN<",
      %(href="#{catalog_entry_path(entry)}"))
  end

  it "shows owned quantities and fades printings you don't own", :aggregate_failures do
    owned = printing("Lightning Bolt")
    create(:lot, account: user.account, entry: owned, quantity: 3)
    create(:lot, entry: owned, quantity: 7) # someone else's copies
    unowned = printing("Lightning Bolt", identity: owned.identity, language: "ja")

    search(q: "bolt")

    expect(response.body).to include(">×3<")
    expect(response.body).not_to include(">×7<", ">×10<")
    expect(response.body).to match(/class="c-tile c-tile--owned-none" href="#{Regexp.escape(catalog_entry_path(unowned))}"/)
  end

  it "counts matching cards on the line under the filter bar" do
    printing("Lightning Bolt")
    search(q: "bolt")
    expect(response.body).to include('<div class="c-results__meta"><span class="c-filterbar__count">1 card</span>')
  end

  it "puts each add button outside its tile link, named for what it adds", :aggregate_failures do
    entry = printing("Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146")
    search(q: "bolt")
    html = Nokogiri::HTML(response.body)
    expect(html.css("a.c-tile form, a.c-tile button")).to be_empty
    expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(entry, :tile)} button")["aria-label"]).to eq("Add 1 × Lightning Bolt (M10 · 146)")
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
    expect(response.body).to include(%(No cards match "nothing matches". Check the spelling or try part of the name.))
  end

  it "prompts for a name when the query is blank or whitespace" do
    search(q: "   ")

    expect(response.body).to include("Type part of a card name to search.")
  end

  it "treats wildcard characters literally" do
    printing("Fires of Yavimaya")

    search(q: "Fire_")

    expect(response.body).to include(%(No cards match "Fire_".))
  end

  it "hides tokens, emblems, art cards and retired printings", :aggregate_failures do
    printing("Goblin Token", kind: "token")
    printing("Ajani Emblem", kind: "emblem")
    printing("Goblin Art", kind: "art_card")
    printing("Goblin Retired", retired_at: 1.day.ago)

    search(q: "goblin")

    expect(response.body).to include(%(No cards match "goblin".))
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
    expect(response.body).to include(%(No cards match "bolt".))
  end

  it "says the catalog has not been loaded until a refresh has applied" do
    create(:catalog_refresh_run, status: "failed")

    search

    expect(response.body).to include("The card catalog hasn't been loaded yet.")
  end

  it "shows the date of the last applied refresh" do
    create(:catalog_refresh_run, finished_at: Time.zone.local(2026, 9, 28, 3, 20))

    search

    expect(response.body).to include("Catalog updated 28 September 2026")
  end

  it "makes no outbound requests while rendering" do
    printing("Lightning Bolt", image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")

    search(q: "bolt")

    expect(a_request(:any, /.*/)).not_to have_been_made
  end
end
