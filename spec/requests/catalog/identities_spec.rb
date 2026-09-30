require "rails_helper"

RSpec.describe "Card printings", type: :request do
  before { sign_in_as(create(:user)) }

  let(:forest) { create(:catalog_identity, name: "Forest", external_key: "oracle-forest") }

  it "lists printings newest first, 12 per page", :aggregate_failures do
    entries = Array.new(25) { |i| create(:catalog_entry, identity: forest, released_on: Date.new(2000, 1, 1) + i) }

    get catalog_identity_path(forest)

    expect(response.body).to include("Forest", "Page 1 of 3")
    expect(response.body.index(catalog_entry_path(entries.last))).to be < response.body.index(catalog_entry_path(entries[-2]))
    expect(response.body.scan(%r{href="/catalog/entries/}).size).to eq(12)
  end

  it "keeps a set filter and offers to show all sets", :aggregate_failures do
    a = create(:catalog_entry, identity: forest, set: create(:catalog_set, code: "aaa"))
    b = create(:catalog_entry, identity: forest, set: create(:catalog_set, code: "bbb"))

    get catalog_identity_path(forest, set: "aaa")

    expect(response.body).to include(catalog_entry_path(a), "Show all sets")
    expect(response.body).not_to include(catalog_entry_path(b))
  end

  it "returns 404 for an unknown card" do
    get "/catalog/identities/nope"

    expect(response).to have_http_status(:not_found)
  end

  it "makes no outbound requests while rendering" do
    create(:catalog_entry, identity: forest, image_url: "https://cards.scryfall.io/normal/front/a/b/forest.jpg")

    get catalog_identity_path(forest)

    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it "returns 404 for a card without searchable printings" do
    create(:catalog_entry, :retired, identity: forest)

    get catalog_identity_path(forest)

    expect(response).to have_http_status(:not_found)
  end
end
