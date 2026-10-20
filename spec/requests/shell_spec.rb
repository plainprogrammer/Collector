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

  it "links the account menu and More to the export, outside Turbo and never prefetched", :aggregate_failures do
    [ collection_path, more_path ].each do |path|
      get path
      link = Nokogiri::HTML5(response.body).css("a[href='#{collection_export_path}']")
      expect(link.map(&:text)).to include("Export collection")
      expect(link.map { |a| [ a["data-turbo"], a["data-turbo-prefetch"], a["download"] ] }.uniq).to eq([ [ "false", "false", nil ] ])
    end
    expect(Nokogiri::HTML5(response.body).at_css(".c-more li:nth-child(2) a")&.text).to eq("Export collection")
  end

  it "puts the import right after the export, in the account menu and on More (spec 025 AC-5.1, AC-5.2)", :aggregate_failures do
    get more_path
    page = Nokogiri::HTML5(response.body)

    expect(page.css(".c-appbar .c-menu__list a.c-menu__item").map(&:text).first(2)).to eq([ "Export collection", "Import collection" ])
    expect(page.at_css(".c-more li:nth-child(3) a")&.then { |link| [ link.text, link["href"] ] })
      .to eq([ "Import collection", new_collection_import_preview_path ])
  end

  it "puts the export in the account menu for a collector who isn't an admin" do
    get collection_path

    expect(Nokogiri::HTML5(response.body).at_css(".c-appbar .c-menu__list a.c-menu__item[href='#{collection_export_path}']")&.text).to eq("Export collection")
  end
end
