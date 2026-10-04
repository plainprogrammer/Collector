require "rails_helper"

RSpec.describe "Collection table", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def rows = page_html.css("table.c-table tbody tr")
  def cells(row) = row.css("td").map { |cell| cell.text.squish }
  def header(label) = page_html.css("table.c-table thead th").find { |th| th.text.strip == label }

  it "shows one row per lot with printing, language, finish, condition, quantity and price paid", :aggregate_failures do
    foil = own("Lightning Bolt", number: "146", quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
    create(:lot, account: user.account, entry: foil.entry, finish: "nonfoil")
    opt = own("Opt", language: "ja", localized_name: "選択")
    get collection_path(view: "table")
    bolt_set = "#{foil.entry.set.code.upcase} · 146"
    expect(rows.map { |row| row.at_css("td a")&.text }).to eq([ "Lightning Bolt", "Lightning Bolt", "選択" ])
    expect(rows.map { |row| cells(row)[1..6] }).to eq([
      [ bolt_set, "EN", "Nonfoil", "—", "1", "—" ],
      [ bolt_set, "EN", "Foil", "NM", "2", "$1.25" ],
      [ "#{opt.entry.set.code.upcase} · #{opt.entry.number}", "JA", "—", "—", "1", "—" ]
    ])
    expect(rows[0].at_css("td:nth-child(4) span.is-muted")&.text).to eq("Nonfoil")
    expect(rows[1].at_css("td:nth-child(4) .is-muted")).to be_nil
    expect(rows[1].at_css("td a")["href"]).to eq(catalog_entry_path(foil.entry, from: "collection"))
    expect(rows[1].at_css(".c-table__sub").text).to eq("#{bolt_set} · Foil · NM · EN")
  end

  it "keeps the grid's page head, Add items and count", :aggregate_failures do
    own("Lightning Bolt", quantity: 3)
    own("Opt", quantity: 2)
    get collection_path(view: "table", q: "bolt")
    expect(response.body).to include("5 items · 2 unique", "3 of 5 items")
    expect(page_html.at_css(".c-pagehead__actions a.c-btn--primary")["href"]).to eq(catalog_entries_path)
    expect(rows.size).to eq(1)
  end

  it "says when the filter matches nothing" do
    own
    get collection_path(view: "table", q: "zzz")
    expect([ response.body.include?(%(No cards in your collection match "zzz".)), response.body.include?("0 of 1 item<"), rows.size ])
      .to eq([ true, true, 0 ])
  end

  it "pages and falls back to the nearest real page", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 2)
    3.times { |n| own("Card #{n}") }
    get collection_path(view: "table")
    expect(rows.size).to eq(2)
    expect(page_html.at_css(".c-pager__position").text).to eq("Page 1 of 2")
    expect(page_html.at_css("a[rel=next]")["href"]).to eq(collection_path(page: 2, view: "table"))
    get collection_path(view: "table", page: "99")
    expect([ response.status, rows.size ]).to eq([ 200, 1 ])
  end

  it "gives each row an actions menu named after the lot", :aggregate_failures do
    lot = own("Lightning Bolt", number: "146", finish: "foil", condition: "near_mint")
    get collection_path(view: "table")
    menu = rows.sole.at_css("td.c-table__actions details.c-menu")
    expect(menu.at_css("summary")["aria-label"]).to eq("Actions for Lightning Bolt #{lot.entry.set.code.upcase} · 146 Foil NM")
    expect(menu.css(".c-menu__item").map(&:text)).to eq([ "Edit copy", "Remove" ])
    return_to = collection_path(view: "table")
    expect(menu.css("a").map { |link| link["href"] }).to eq([
      edit_lot_path(lot, from: "collection", return_to:), new_lot_removal_path(lot, from: "collection", return_to:)
    ])
  end

  it "keeps rows of retired printings" do
    own.entry.update!(retired_at: 1.day.ago)
    get collection_path(view: "table")
    expect(rows.size).to eq(1)
  end

  it "shows the empty state and no table for an empty collection", :aggregate_failures do
    get collection_path(view: "table")
    expect(response.body).to include("No cards in your collection yet.")
    expect(response.body).not_to include("c-table")
  end

  describe "sorting" do
    it "links every sortable header and marks Name ascending by default", :aggregate_failures do
      own
      get collection_path(view: "table")
      sortable = page_html.css("table.c-table thead th").select { |th| th.at_css("a.c-table__sort") }
      expect(sortable.map { |th| [ th.text.strip, th["aria-sort"], th.at_css("a")["href"] ] }).to eq([
        [ "Name", "ascending", collection_path(view: "table", sort: "name", dir: "desc") ],
        [ "Set", "none", collection_path(view: "table", sort: "set", dir: "asc") ],
        [ "Condition", "none", collection_path(view: "table", sort: "condition", dir: "asc") ],
        [ "Qty", "none", collection_path(view: "table", sort: "quantity", dir: "asc") ],
        [ "Paid", "none", collection_path(view: "table", sort: "price", dir: "asc") ]
      ])
    end

    it "states the chosen column's direction and reverses it, keeping the filter but not the page", :aggregate_failures do
      own
      get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc", page: 1)
      expect([ header("Paid")["aria-sort"], header("Paid").at_css("a")["href"] ])
        .to eq([ "descending", collection_path(view: "table", q: "bolt", sort: "price", dir: "asc") ])
      expect(header("Name")["aria-sort"]).to eq("none")
    end

    it "keeps the sort when paging and filtering", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      2.times { |n| own("Card #{n}") }
      get collection_path(view: "table", sort: "quantity", dir: "desc", page: 2)
      expect(page_html.at_css("a[rel=prev]")["href"]).to eq(collection_path(view: "table", sort: "quantity", dir: "desc", page: 1))
      hidden = page_html.css("form.c-filterbar input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
      expect(hidden).to eq("sort" => "quantity", "dir" => "desc")
    end

    it "uses the default order for an unknown sort" do
      own
      get collection_path(view: "table", sort: "bogus", dir: "up")
      expect([ response.status, header("Name")["aria-sort"] ]).to eq([ 200, "ascending" ])
    end

    it "leaves the grid in its own order", :aggregate_failures do
      own("Opt", quantity: 9)
      own("Lightning Bolt", quantity: 1)
      get collection_path(sort: "quantity", dir: "desc")
      expect(page_html.css(".c-grid .c-tile__name").map(&:text)).to eq([ "Lightning Bolt", "Opt" ])
    end
  end
end
