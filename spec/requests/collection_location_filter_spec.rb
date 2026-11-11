require "rails_helper"

RSpec.describe "Filtering the collection by location", type: :request do # spec 037
  let(:user) { create(:user) }
  let(:blue) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def account = user.account
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def tiles = page_html.css(".c-tile").map { [ it.at_css(".c-tile__name").text.squish, it.at_css(".c-tile__qty").text.squish ] }
  def rows = page_html.css("tbody tr").map { it.at_css("td").text.squish }
  def count_line = page_html.at_css(".c-results__meta .c-filterbar__count").text.squish
  def selection = BulkSelection.find_by(session: user.sessions.last)

  describe "the page" do
    it "shows only a place's printings with that place's copies, without place lines (AC-1.2, AC-1.4)", :aggregate_failures do
      entry = own("Lightning Bolt", quantity: 3, location: blue).entry
      create(:lot, account:, entry:, quantity: 2, location: box, finish: "foil")
      own("Opt", quantity: 4, location: box)
      get collection_path(location: blue.id, view: "grid")
      expect(response).to have_http_status(:ok)
      expect(tiles).to eq([ [ "Lightning Bolt", "×3" ] ])
      expect([ page_html.css(".c-tile__place"), page_html.css(".c-tile__flags") ]).to all(be_empty)
      expect(count_line).to eq("3 of 9 items")
      expect(page_html.at_css(".c-pagehead__stats").text.squish).to eq("9 items · 2 unique")
    end

    it "shows only the place's rows in the table (AC-1.3)" do
      own("Lightning Bolt", location: blue)
      own("Lightning Bolt", location: box)
      own("Opt")
      get collection_path(location: blue.id, view: "table")
      expect([ rows.size, count_line ]).to eq([ 1, "1 of 3 items" ])
    end

    it "shows only unplaced lots for none (AC-2.1)", :aggregate_failures do
      own("Lightning Bolt", location: blue)
      own("Opt", quantity: 2)
      get collection_path(location: "none", view: "grid")
      expect([ tiles, count_line ]).to eq([ [ [ "Opt", "×2" ] ], "2 of 3 items" ])
    end

    it "joins the name filter (AC-3.1)" do
      own("Lightning Bolt", location: blue)
      own("Opt", location: blue)
      own("Lightning Bolt", location: box, finish: "foil")
      get collection_path(location: blue.id, q: "bolt", view: "grid")
      expect([ tiles, count_line ]).to eq([ [ [ "Lightning Bolt", "×1" ] ], "1 of 3 items" ])
    end

    it "ignores the parameter while the account has no location (AC-6.1)", :aggregate_failures do
      own("Opt", quantity: 2)
      get collection_path(location: "none", view: "grid")
      expect([ response.status, tiles, count_line ]).to eq([ 200, [ [ "Opt", "×2" ] ], "2 items" ])
    end

    it "does not save the location with the view (AC-4.2)", :aggregate_failures do
      own(location: blue)
      own("Opt")
      get collection_path(location: blue.id, view: "table")
      expect(user.reload.collection_view).to eq("table")
      get collection_path
      expect(count_line).to eq("2 items")
    end
  end

  describe "values that name no location of the account (decision 7, AC-6.2)" do
    let(:other) { create(:user).account }
    let(:theirs) { create(:location, account: other, name: "Their secret binder") }

    it "shows the whole collection, unfiltered, and nothing of the other account", :aggregate_failures do
      stub_const("CollectionGrid::PER_PAGE", 1)
      own("Lightning Bolt", location: blue)
      own("Opt")
      owned_printing("Shock", account: other, location: theirs)
      gone = create(:location, account:).tap(&:destroy!)
      [ theirs.id.to_s, gone.id.to_s, "abc", "017", "", "NONE", "1#{"0" * 18}" ].each do |value|
        get collection_path(location: value, view: "grid")
        expect([ response.status, count_line, page_html.at_css(".c-pager__position")&.text ]).to eq([ 200, "2 items", "Page 1 of 2" ])
        expect(response.body).not_to include("Shock", "Their secret binder")
      end
    end

    it "reads a non-string parameter as all", :aggregate_failures do
      own(location: blue)
      own("Opt")
      %w[location[]=1 location[a]=1].each do |query|
        get "#{collection_path}?view=grid&#{query}"
        expect([ response.status, count_line ]).to eq([ 200, "2 items" ])
      end
    end
  end

  describe "the links' URLs" do
    include CollectionsHelper

    it "keeps location in a collection URL and leaves it out for all", :aggregate_failures do
      expect(collection_listing_path(location: "17", query: "bolt")).to eq(collection_path(q: "bolt", location: "17"))
      expect(collection_listing_path(location: "", query: "bolt")).to eq(collection_path(q: "bolt"))
      expect(collection_listing_path(bulk: 1, location: "none")).to eq(collection_path(bulk: 1, location: "none"))
    end
  end

  describe "bulk mode (Story 5)" do
    def start_bulk(**params)
      post collection_selection_path, params: params.compact
      follow_redirect!
    end

    def submit_bulk(go:, location: "", rendered_location: location, q: "", rendered_q: q, shown: [], ticked: [], all: false, page: nil)
      params = { go:, q:, rendered_q:, location:, rendered_location:, page:, shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id),
        all_rendered: "0", header_toggled: "0" }
      params[:all] = "1" if all
      patch collection_selection_path, params: params.compact
    end

    it "opens Edit many under the location and stores it (AC-5.1)", :aggregate_failures do
      own(location: blue, quantity: 2)
      own("Opt")
      post collection_selection_path, params: { location: blue.id, q: "bolt" }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt", location: blue.id))
      expect(selection.location_filter).to eq(blue.id.to_s)
      follow_redirect!
      expect([ page_html.at_css(".c-bulkbar__count").text, count_line ]).to eq([ "0 of 2 selected", "2 of 3 items" ])
    end

    it "restarts under the new filter pair on Filter and carries it", :aggregate_failures do
      lot = own(location: blue)
      start_bulk
      submit_bulk(go: "filter", location: blue.id.to_s, rendered_location: "", shown: [ lot ], ticked: [ lot ])
      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      expect([ selection.location_filter, selection.marks.count ]).to eq([ blue.id.to_s, 0 ])
    end

    it "keeps the page only when neither filter changed", :aggregate_failures do
      own(location: blue)
      start_bulk(location: blue.id)
      submit_bulk(go: "filter", location: blue.id.to_s, page: "2")
      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id, page: 2))
      submit_bulk(go: "filter", location: "none", rendered_location: blue.id.to_s, page: "2")
      expect(response).to redirect_to(collection_path(bulk: 1, location: "none"))
    end

    it "uses the rendered location for Next, a sort, Remove and Done, not the select's (AC-5.3)", :aggregate_failures do
      lot = own(location: blue)
      start_bulk(location: blue.id)
      next_page = collection_path(bulk: 1, location: blue.id, page: 2)
      submit_bulk(go: next_page, location: "none", rendered_location: blue.id.to_s, shown: [ lot ], ticked: [ lot ])
      expect(response).to redirect_to(next_page)
      expect([ selection.location_filter, selection.lots ]).to eq([ blue.id.to_s, [ lot ] ])
      submit_bulk(go: "remove", location: "none", rendered_location: blue.id.to_s)
      expect(response).to redirect_to(new_collection_bulk_removal_path)
      submit_bulk(go: "done", location: "none", rendered_location: blue.id.to_s, q: "bo", rendered_q: "bolt")
      expect(response).to redirect_to(collection_path(q: "bolt", location: blue.id))
    end

    it "carries the location of a pager or sort URL", :aggregate_failures do
      own(location: blue)
      start_bulk
      submit_bulk(go: collection_path(bulk: 1, location: "none", sort: "price", dir: "desc"))
      expect(response).to redirect_to(collection_path(bulk: 1, location: "none", sort: "price", dir: "desc"))
      expect(selection.location_filter).to eq("none")
    end

    it "acts on nothing selected under another location than the selection's (AC-5.3)" do
      lot = own(location: blue)
      start_bulk(location: blue.id)
      submit_bulk(go: "filter", location: blue.id.to_s, shown: [ lot ], ticked: [ lot ])
      submit_bulk(go: "remove", rendered_location: "none")
      expect([ response.status, Lot.exists?(lot.id), selection.location_filter ]).to eq([ 422, true, "none" ])
    end

    it "removes only the place's lots after Select all, and keeps the location after (AC-5.2, AC-5.6)", :aggregate_failures do
      inside = own("Lightning Bolt", location: blue)
      outside = own("Lightning Bolt", location: box, finish: "foil")
      start_bulk(location: blue.id)
      submit_bulk(go: "remove", location: blue.id.to_s, shown: [ inside, outside ], ticked: [ inside, outside ], all: true)
      expect(response).to redirect_to(new_collection_bulk_removal_path)
      post collection_bulk_removals_path
      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      expect([ Lot.exists?(inside.id), Lot.exists?(outside.id) ]).to eq([ false, true ])
      expect(selection.context?("", CollectionTable::Sort.parse(nil, nil), location: blue.id.to_s)).to be(true)
    end

    it "returns Set condition to the bulk table under the location (AC-5.6)" do
      lot = own(location: blue)
      start_bulk(location: blue.id, q: "bolt")
      submit_bulk(go: "set_condition", location: blue.id.to_s, q: "bolt", shown: [ lot ], ticked: [ lot ])
      post collection_condition_change_path, params: { condition: "near_mint" }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt", location: blue.id))
    end

    it "removes nothing of another account's for its location id", :aggregate_failures do
      other = create(:location)
      theirs = owned_printing("Shock", account: other.account, location: other)
      own("Opt")
      start_bulk
      [ { location: theirs.location_id.to_s, rendered_location: "" }, { location: "", rendered_location: theirs.location_id.to_s } ].each do |values|
        submit_bulk(go: "remove", all: true, **values)
        post collection_bulk_removals_path if response.redirect?
      end
      expect(Lot.exists?(theirs.id)).to be(true)
    end

    describe "a location removed in another tab (AC-5.8, AC-5.5)" do
      let!(:unplaced) { own("Opt") }
      let(:gone) { create(:location, account:, name: "Gone binder") }

      it "refuses with nothing removed whether or not the rendered location matches the selection", :aggregate_failures do
        [ gone.id, nil ].each do |started_under|
          location = gone.id.to_s
          start_bulk(location: started_under)
          create(:location, account:) # keeps the account with a location after the removal
          Location.where(id: gone.id).destroy_all
          submit_bulk(go: "remove", location:, all: true)
          expect([ response.status, page_html.at_css(".c-status__message--alert").text ]).to eq([ 422, BulkSelection::NONE_LEFT ])
          expect([ Lot.exists?(unplaced.id), count_line ]).to eq([ true, "1 item" ])
        end
      end
    end

    it "re-renders a refusal under a location that still exists (AC-5.6)", :aggregate_failures do
      own(location: blue)
      own("Opt")
      start_bulk(location: blue.id)
      submit_bulk(go: "remove", location: blue.id.to_s)
      expect([ response.status, count_line ]).to eq([ 422, "1 of 2 items" ])
    end

    it "returns Undo to the URL with the location and re-renders its refusal under it (AC-5.6)", :aggregate_failures do
      own(location: blue)
      own("Opt")
      start_bulk(location: blue.id)
      submit_bulk(go: "remove", location: blue.id.to_s, all: true)
      post collection_bulk_removals_path
      removal = BulkRemoval.last
      return_to = collection_path(bulk: 1, location: blue.id)
      post collection_bulk_removal_undo_path(removal), params: { return_to: }
      expect(response).to redirect_to(return_to)
      post collection_bulk_removal_undo_path(removal), params: { return_to: }
      expect([ response.status, count_line ]).to eq([ 422, "1 of 2 items" ])
    end
  end

  # Spec 062 AC-5.8: a lot in a zone is in no place and not unplaced. Spec 062 D6, AC-5.2 (a zone or a deck is never a filter value)
  # is superseded by spec 065 decision 4: a zone's id is a value, a deck's own id without its `deck:` prefix still reads as all.
  describe "with a deck (spec 062, spec 065)" do
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")

    def three_lots
      blue
      zoned = create_lot_in_zone(deck, "main", entry: create(:mtg_printing).entry.tap { it.update!(name: "Zone card") }, quantity: 2)
      [ zoned, own("Place card", location: blue), own("Loose card") ]
    end

    it "reads a deck's own id as all, in both views (spec 065 decision 4)", :aggregate_failures do
      three_lots
      %w[grid table].each do |view|
        get collection_path(location: deck.location_id, view:)
        expect([ response.status, count_line ]).to eq([ 200, "4 items" ]), "#{view} #{deck.location_id}"
      end
    end

    it "filters to a zone's lots by its id, in both views (spec 065 AC-6.2)", :aggregate_failures do
      three_lots
      %w[grid table].each do |view|
        get collection_path(location: deck.zone("main").id, view:)
        expect([ response.status, count_line ]).to eq([ 200, "2 of 4 items" ]), "#{view} #{deck.zone('main').id}"
      end
    end

    it "puts a lot in a zone in neither No location nor a place, and shows it under All locations (AC-5.8)", :aggregate_failures do
      three_lots
      { "none" => [ "Loose card" ], blue.id.to_s => [ "Place card" ], "" => [ "Loose card", "Place card", "Zone card" ] }.each do |value, names|
        get collection_path(location: value, view: "table")
        expect(page_html.css("tbody tr").map { it.at_css("td a").text }).to match_array(names), value
      end
    end
  end
end
