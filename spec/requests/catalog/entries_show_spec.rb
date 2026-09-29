require "rails_helper"

RSpec.describe "Printing detail", type: :request do
  let(:set) { create(:catalog_set, code: "neo", name: "Kamigawa: Neon Dynasty", released_on: Date.new(2022, 2, 18)) }
  let(:identity) { create(:catalog_identity, name: "Azusa's Many Journeys // Likeness of the Seeker") }
  let(:entry) do
    create(:catalog_entry, external_key: "ec725e92", set:, identity:, number: "172", language: "ja",
      localized_name: "梓の幾多の旅 // 探求者の肖像", released_on: Date.new(2022, 2, 18))
  end

  before do
    create(:mtg_printing, entry:, rarity: "uncommon", finishes: %w[foil nonfoil],
      scryfall_uri: "https://scryfall.com/card/neo/172/ja/azusa",
      faces: [
        { "name" => "Azusa's Many Journeys", "printed_name" => "梓の幾多の旅", "mana_cost" => "{1}{G}",
          "type_line" => "Enchantment — Saga", "oracle_text" => "Chapter one", "artist" => "Lindsey Look",
          "image_uris" => { "large" => "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg" } },
        { "name" => "Likeness of the Seeker", "printed_name" => "探求者の肖像", "mana_cost" => "",
          "type_line" => "Enchantment Creature — Human Monk", "oracle_text" => "<script>x</script>Blocked",
          "artist" => "Lindsey Look", "image_uris" => { "large" => "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg" } }
      ])
  end

  it "is addressed by the Scryfall ID and shows everything about the printing", :aggregate_failures do
    get "/catalog/entries/ec725e92"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Azusa&#39;s Many Journeys // Likeness of the Seeker", "梓の幾多の旅 // 探求者の肖像",
      "Kamigawa: Neon Dynasty", "NEO", "172", "ja", "Uncommon", "foil, nonfoil", "February 18, 2022",
      "{1}{G}", "Enchantment — Saga", "Chapter one", "Enchantment Creature — Human Monk", "Lindsey Look",
      "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg", "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg")
  end

  it "escapes source text" do
    get catalog_entry_path(entry)

    expect(response.body).not_to include("<script>x</script>")
  end

  it "links to Scryfall with attribution and to the card's printings", :aggregate_failures do
    get catalog_entry_path(entry)

    expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"', "provided by Scryfall",
      catalog_identity_path(identity), catalog_entries_path(q: identity.name))
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
end
