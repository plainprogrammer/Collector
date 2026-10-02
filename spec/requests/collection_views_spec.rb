require "rails_helper"

RSpec.describe "Collection views", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def switch = page_html.at_css(".c-filterbar .c-seg[role=group][aria-label=View]")

  it "offers Grid and Table as buttons of the view-switch form, marking the one shown", :aggregate_failures do
    own
    get collection_path
    expect(switch.css("button").map { |b| [ b.text.strip, b["aria-pressed"], b["type"], b["form"], b["name"], b["value"] ] }).to eq([
      [ "Grid", "true", "submit", "view-switch", "view", "grid" ], [ "Table", "false", "submit", "view-switch", "view", "table" ]
    ])
    get collection_path(view: "table")
    expect(switch.css("button[aria-pressed=true]").map { |b| b.text.strip }).to eq([ "Table" ])
  end

  it "submits the switch to the whole page with the current filter and sort", :aggregate_failures do
    own
    get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc")
    form = page_html.at_css("form#view-switch")
    expect([ form["method"], form["action"], form["data-turbo-frame"], form.key?("hidden") ]).to eq([ "get", collection_path, nil, true ])
    expect(form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }).to eq("q" => "bolt", "sort" => "price", "dir" => "desc")
  end

  it "shows the grid to a collector who never chose", :aggregate_failures do
    own
    get collection_path
    expect([ user.reload.collection_view, response.body.include?('class="c-grid"') ]).to eq([ "grid", true ])
  end

  it "saves a chosen view and shows it on later visits, after signing in again", :aggregate_failures do
    own
    get collection_path(view: "table")
    expect(user.reload.collection_view).to eq("table")
    delete session_path
    sign_in_as(user)
    get collection_path
    expect(response.body).to include('<table class="c-table">')
  end

  it "shows the saved view for an unknown view and keeps it", :aggregate_failures do
    own
    user.update!(collection_view: "table")
    get collection_path(view: "carousel")
    expect([ response.status, response.body.include?('<table class="c-table">'), user.reload.collection_view ]).to eq([ 200, true, "table" ])
  end

  it "keeps each collector's choice their own" do
    other = create(:user)
    own
    get collection_path(view: "table")
    expect(other.reload.collection_view).to eq("grid")
  end

  it "never saves a view from a prefetch", :aggregate_failures do
    own
    get collection_path(view: "table"), headers: { "X-Sec-Purpose" => "prefetch" }
    expect(response.body).to include('<table class="c-table">')
    get collection_path(view: "table"), headers: { "Sec-Purpose" => "prefetch;prerender" }
    expect(user.reload.collection_view).to eq("grid")
  end

  it "never saves a view from a Firefox or legacy prefetch", :aggregate_failures do
    own
    get collection_path(view: "table"), headers: { "X-Moz" => "prefetch" }
    expect(user.reload.collection_view).to eq("grid")
    get collection_path(view: "table"), headers: { "Purpose" => "prefetch" }
    expect(user.reload.collection_view).to eq("grid")
  end

  it "has no switch and no table on an empty collection, whatever the saved view", :aggregate_failures do
    user.update!(collection_view: "table")
    get collection_path
    expect(response.body).not_to include("c-seg", "c-table")
  end
end
