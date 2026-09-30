require "rails_helper"

RSpec.describe "App shell", type: :request do
  before { sign_in_as(create(:user, name: "james")) }

  it "shows the brand, Collection then Search, and the avatar menu", :aggregate_failures do
    get catalog_entries_path
    nav = response.body[%r{<nav class="c-appbar__nav".*?</nav>}m]
    expect(nav.index("Collection")).to be < nav.index("Search")
    # link_to writes its html options before href.
    expect(nav).to include(%(aria-current="page" href="#{catalog_entries_path}">Search</a>))
    expect(nav.scan('aria-current="page"').size).to eq(1)
    expect(response.body).to include('aria-label="Account: james"', ">J<", "Sign out", 'aria-label="Collector home"')
  end

  it "shows the tab bar with Collection, Search and More, marking the current section", :aggregate_failures do
    get collection_path
    tabbar = response.body[%r{<nav class="c-tabbar".*?</nav>}m]
    expect(tabbar).to include("Collection", "Search", "More")
    expect(tabbar).to include(%(aria-current="page" href="#{collection_path}">))
    expect(tabbar.scan('aria-current="page"').size).to eq(1)
  end

  it "shows an icon-only add button that leads to search" do
    get collection_path
    expect(response.body).to include(
      %(class="c-btn c-btn--primary c-btn--sm c-btn--icon c-appbar__add" aria-label="Add items" href="#{catalog_entries_path}"))
  end

  it "redirects the root to the collection" do
    get root_path
    expect(response).to redirect_to(collection_path)
  end

  it "offers sign out on the More page and marks no section", :aggregate_failures do
    get more_path
    expect(response.body).to include("Sign out", "Signed in as")
    expect(response.body).not_to include('aria-current="page"')
  end

  it "uses the page head on the More page" do
    get more_path
    expect(response.body).to include('<div class="c-pagehead">')
  end
end
