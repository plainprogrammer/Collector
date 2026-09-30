require "rails_helper"

RSpec.describe "Card page", type: :request do
  let(:user) { create(:user) }
  let(:set) { create(:catalog_set, code: "neo", name: "Kamigawa: Neon Dynasty", released_on: Date.new(2022, 2, 18)) }
  let(:identity) { create(:catalog_identity, name: "Azusa's Many Journeys // Likeness of the Seeker") }
  let(:entry) do
    create(:catalog_entry, external_key: "ec725e92", set:, identity:, number: "172", language: "ja",
      localized_name: "梓の幾多の旅 // 探求者の肖像", released_on: Date.new(2022, 2, 18))
  end

  before do
    create(:mtg_printing, entry:, rarity: "uncommon", finishes: %w[foil nonfoil],
      scryfall_uri: "https://scryfall.com/card/neo/172/ja/azusa",
      legalities: { "modern" => "legal", "standard" => "not_legal", "alchemy" => "legal" },
      faces: [
        { "name" => "Azusa's Many Journeys", "printed_name" => "梓の幾多の旅", "mana_cost" => "{1}{G}",
          "type_line" => "Enchantment — Saga", "oracle_text" => "Chapter one", "artist" => "Lindsey Look",
          "image_uris" => { "large" => "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg" } },
        { "name" => "Likeness of the Seeker", "printed_name" => "探求者の肖像", "mana_cost" => "",
          "type_line" => "Enchantment Creature — Human Monk", "oracle_text" => "<script>x</script>Blocked",
          "artist" => "Lindsey Look", "image_uris" => { "large" => "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg" } }
      ])
    sign_in_as(user)
  end

  it "is addressed by the Scryfall ID and shows everything about the printing", :aggregate_failures do
    get "/catalog/entries/ec725e92"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Azusa&#39;s Many Journeys // Likeness of the Seeker", "梓の幾多の旅 // 探求者の肖像",
      "Kamigawa: Neon Dynasty", "NEO · 172", ">JA<", "Uncommon", "Nonfoil, Foil", "18 February 2022",
      'aria-label="Mana cost: 1 generic, 1 green"', "Enchantment — Saga", "Chapter one", "Enchantment Creature — Human Monk",
      "Lindsey Look // Lindsey Look", "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg",
      "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg")
  end

  it "escapes source text" do
    get catalog_entry_path(entry)

    expect(response.body).not_to include("<script>x</script>")
  end

  it "links to Scryfall with attribution, to the card's printings and back to search" do
    get catalog_entry_path(entry)

    expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"', "provided by Scryfall",
      catalog_identity_path(identity), %(<li><a href="#{catalog_entries_path}">Search</a></li>))
  end

  it "renders a retired printing with a notice", :aggregate_failures do
    entry.update!(retired_at: 1.day.ago)

    get catalog_entry_path(entry)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("no longer present in the upstream source")
  end

  it "returns 404 for an unknown Scryfall ID" do
    get "/catalog/entries/does-not-exist"

    expect(response).to have_http_status(:not_found)
  end

  it "makes no outbound requests while rendering" do
    get catalog_entry_path(entry)

    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it "shows the sections in order and only the listed paper formats", :aggregate_failures do
    get catalog_entry_path(entry)

    body = response.body
    order = [ "c-item__image", "c-item__title", "c-chip--cards", "c-rules", "c-details", "<dt>Owned</dt>", "Your copies",
      %(<h2 class="c-section__title">Printings</h2>), "Format legality" ]
    expect(order.map { |marker| body.index(marker) }).to eq(order.map { |marker| body.index(marker) }.sort)
    expect(body).to include("Magic: The Gathering", "Legal", "Not legal", "Standard", "Modern", "Premodern")
    expect(body).not_to include("Alchemy")
  end

  it "counts owned copies across printings and lists lots", :aggregate_failures do
    other = create(:mtg_printing, entry: create(:catalog_entry, identity:)).entry
    create(:lot, account: user.account, entry:, quantity: 3, condition: "near_mint", price_paid_cents: 125)
    create(:lot, account: user.account, entry: other, quantity: 4, finish: "foil")

    get catalog_entry_path(entry)

    expect(response.body).to include("<dd>7</dd>", "2 printings", "7 in 2 lots", "NM", "$1.25", "Foil", "Edit copy", "Remove")
  end

  it "shows the empty copies state with an add action" do
    get catalog_entry_path(entry)
    expect(response.body).to include("You don't have this card yet.", "Add a copy")
  end

  it "lists the shown printing, owned retired printings and a link to all printings", :aggregate_failures do
    retired = create(:catalog_entry, identity:, retired_at: 1.day.ago, set: create(:catalog_set, code: "old"), number: "9")
    create(:lot, account: user.account, entry: retired)

    get catalog_entry_path(entry)

    printings = response.body[%r{<section id="printings">.*?</section>}m]
    expect(printings).to include(%(NEO · 172</span><span class="c-tag">Shown</span>), "OLD · 9", "· Retired", "×1")
    expect(printings).to include("Show all 1 printings", %(href="#{catalog_identity_path(identity)}"))
  end

  it "starts the breadcrumb and section from the collection only when marked", :aggregate_failures do
    get catalog_entry_path(entry, from: "collection")
    expect(response.body).to include(%(<li><a href="#{collection_path}">Collection</a></li>),
      %(aria-current="page" href="#{collection_path}">Collection</a>))
    expect(response.body[%r{<nav class="c-tabbar".*?</nav>}m]).to include(%(aria-current="page" href="#{collection_path}">))

    get catalog_entry_path(entry)
    expect(response.body).to include(%(<li><a href="#{catalog_entries_path}">Search</a></li>),
      %(aria-current="page" href="#{catalog_entries_path}">Search</a>))
  end
end
