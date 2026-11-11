require "rails_helper"

RSpec.describe "Places on the collection's tiles and rows", type: :request do # spec 033
  let(:user) { create(:user) }
  let(:blue) { create(:location, account: user.account, name: "Blue binder") }
  let(:box) { create(:location, account: user.account, name: "Long box") }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def place_lines = page_html.css(".c-tile__place").map { it.text.squish }
  def cells = page_html.css("td.c-table__place").map { it.text.squish }

  # What a tile shows besides its place line (spec 004 AC-11.2, AC-11.3), and the page's counts.
  def tile_facts
    tiles = page_html.css(".c-tile").map do |tile|
      [ tile["href"], tile.at_css(".c-tile__qty").text, tile.css(".c-tile__flags").map { it.text.squish }, tile.css(".c-tile__meta .c-tag").map { it.text.squish } ]
    end
    [ tiles, page_html.at_css(".c-filterbar__count").text.squish, page_html.at_css(".c-pagehead__stats").text.squish ]
  end

  describe "the grid" do
    it "names a printing's place under its name", :aggregate_failures do
      own(location: blue, quantity: 3)
      get collection_path
      expect(place_lines).to eq([ "Blue binder" ])
      expect(page_html.at_css(".c-tile").text).to include("Blue binder")
    end

    it "adds how many other places there are, counting unplaced", :aggregate_failures do
      entry = own(location: blue, quantity: 3).entry
      create(:lot, account: user.account, entry:, location: box, finish: "foil")
      create(:lot, account: user.account, entry:, finish: "etched")
      get collection_path
      expect(place_lines).to eq([ "Blue binder +2 more" ])
    end

    it "orders a tie by comparison key on the rendered tile", :aggregate_failures do # spec 033 AC-1.2, spec 048 AC-2.5
      entry = own(location: create(:location, account: user.account, name: "Beta shelf"), quantity: 2).entry
      create(:lot, account: user.account, entry:, finish: "foil", quantity: 2, location: create(:location, account: user.account, name: "alpha shelf"))
      get collection_path
      expect(place_lines).to eq([ "alpha shelf +1 more" ])
    end

    it "says No location for a printing with none, once the account has a location", :aggregate_failures do
      own
      blue
      get collection_path
      expect(place_lines).to eq([ "No location" ])
    end

    it "shows no place line while the account has no location" do
      own
      get collection_path
      expect(place_lines).to be_empty
    end

    it "escapes a name and keeps it in one element", :aggregate_failures do
      own(location: create(:location, account: user.account, name: "<b>Binder</b> #{'x' * 40}"))
      get collection_path
      expect(response.body).not_to include("<b>Binder</b>")
      expect(page_html.css(".c-tile__place-name").size).to eq(1)
      expect(page_html.at_css(".c-tile__place-name").text).to start_with("<b>Binder</b>")
    end

    it "shows only the signed-in account's places", :aggregate_failures do
      own(location: blue)
      other = create(:user).account
      owned_printing("Opt", account: other, location: create(:location, account: other, name: "Their secret box"))
      get collection_path
      expect(response.body).to include("Blue binder")
      expect(response.body).not_to include("Their secret box")
    end

    it "shows all of a matching printing's places under a name filter, and no other printing", :aggregate_failures do # spec 033 AC-1.8, spec 048 AC-2.1
      bolt = own(location: blue, quantity: 3).entry
      create(:lot, account: user.account, entry: bolt, location: box, finish: "foil")
      own("Opt", location: box)
      get collection_path(q: "bolt")
      expect(page_html.css(".c-tile__name").map { it.text.squish }).to eq([ "Lightning Bolt" ])
      expect(place_lines).to eq([ "Blue binder +1 more" ])
    end

    it "changes nothing about a tile but its place line when the lots are placed", :aggregate_failures do # spec 033 AC-1.7, spec 048 AC-2.6
      foil = own(quantity: 3, finish: "foil")
      create(:lot, account: user.account, entry: foil.entry)
      own("Opt")
      blue

      get collection_path
      unplaced = tile_facts
      expect(place_lines).to eq([ "No location", "No location" ])

      foil.update!(location: blue)
      get collection_path
      expect(tile_facts).to eq(unplaced)
      expect(place_lines).to eq([ "Blue binder +1 more", "No location" ])
    end

    it "shows no place on the catalog's tiles" do
      own(location: blue)
      get catalog_entries_path(q: "bolt")
      expect(page_html.css(".c-tile__place")).to be_empty
    end
  end

  describe "the table" do
    it "has a Location column after Qty and before Paid", :aggregate_failures do
      own(location: blue)
      get collection_path(view: "table")
      expect(page_html.css("thead th").map { it.text.squish }).to eq([ "Name", "Set", "Language", "Finish", "Condition", "Qty", "Location", "Paid", "Actions" ])
      expect(cells).to eq([ "Blue binder" ])
    end

    it "escapes a name on the row, in the cell's span and in the line under the name", :aggregate_failures do # spec 048 AC-1.5
      own(location: create(:location, account: user.account, name: "<b>Binder</b> #{'x' * 40}"))
      get collection_path(view: "table")
      expect(response.body).not_to include("<b>Binder</b>")
      expect(page_html.at_css("td.c-table__place .c-table__place-name").text).to start_with("<b>Binder</b>")
      expect(page_html.at_css(".c-table__sub").text).to include("<b>Binder</b>")
    end

    it "shows only the matching lots' rows under a name filter, each with its place", :aggregate_failures do # spec 048 AC-2.1
      bolt = own(location: blue, quantity: 3).entry
      create(:lot, account: user.account, entry: bolt, location: box, finish: "foil")
      own("Opt", location: box)
      get collection_path(view: "table", q: "bolt")
      expect(page_html.css("tbody tr").size).to eq(2)
      expect(cells).to contain_exactly("Blue binder", "Long box")
    end

    it "says No location in muted ink for an unplaced lot", :aggregate_failures do
      own
      blue
      get collection_path(view: "table")
      expect(page_html.css("td.c-table__place.is-muted").map { it.text.squish }).to eq([ "No location" ])
    end

    it "has no column and no place on the phone line without locations", :aggregate_failures do
      own
      get collection_path(view: "table")
      expect(page_html.css("thead th").map { it.text.squish }).not_to include("Location")
      expect(page_html.at_css(".c-table__sub").text).not_to include("location")
    end

    it "adds the place last to the line under the name, and leaves unplaced out", :aggregate_failures do
      own(location: blue, finish: "foil")
      own("Opt")
      get collection_path(view: "table")
      expect(page_html.css(".c-table__sub").map { it.text.squish }).to contain_exactly(a_string_ending_with("EN · Blue binder"), a_string_ending_with("EN"))
    end

    it "does not sort by location", :aggregate_failures do
      own(location: blue)
      get collection_path(view: "table")
      expect(page_html.css("thead th").find { it.text.squish == "Location" }.css("a, button")).to be_empty
    end

    it "shows the same place in bulk mode", :aggregate_failures do
      own(location: blue)
      get collection_path(bulk: "1")
      expect(cells).to eq([ "Blue binder" ])
    end

    it "shows a renamed location's new name" do
      own(location: blue)
      blue.update!(name: "Navy binder")
      get collection_path(view: "table")
      expect(cells).to eq([ "Navy binder" ])
    end

    it "shows only the signed-in account's places" do
      own(location: blue)
      other = create(:user).account
      owned_printing("Opt", account: other, location: create(:location, account: other, name: "Their secret box"))
      get collection_path(view: "table")
      expect(response.body).not_to include("Their secret box")
    end
  end

  describe "after a bulk action (spec 033 AC-2.6, spec 048 AC-2.3)" do
    def select_lots(*lots, go:)
      post collection_selection_path
      patch collection_selection_path, params: { go:, q: "", rendered_q: "", all_rendered: "0",
        shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
    end

    it "keeps each lot's place when Set condition is applied", :aggregate_failures do
      placed = own(location: blue)
      loose = own("Opt")
      select_lots(placed, loose, go: "set_condition")
      post collection_condition_change_path, params: { condition: "lightly_played" }
      expect([ placed.reload.condition, loose.reload.condition ]).to eq(%w[lightly_played lightly_played])
      follow_redirect!
      expect(cells).to eq([ "Blue binder", "No location" ])
    end

    it "keeps each lot's place when a bulk Remove is undone from the bulk table's message", :aggregate_failures do
      placed = own(location: blue)
      loose = own("Opt")
      own("Shock") # not selected, so the bulk table the message appears on still has a row
      select_lots(placed, loose, go: "remove")
      post collection_bulk_removals_path
      follow_redirect!
      undo = page_html.at_css(".c-status form.c-status__action")
      return_to = undo.at_css("input[name=return_to]")["value"]
      expect(return_to).to eq(collection_path(bulk: 1))
      post undo["action"], params: { return_to: }
      follow_redirect!
      expect(user.account.lots.count).to eq(3)
      expect(cells).to eq([ "Blue binder", "No location", "No location" ])
    end
  end

  # Spec 062 AC-5.8a: the place line and the Location column show while the account has a place or a lot in a zone (a lot in a
  # zone has a place to read). The selects, the filter and Move to… now show while the account has a place or a zone (spec 065
  # decision 3 supersedes AC-5.8a here: a deck's zones are choices); the column's gate changes with spec 065 AC-6.9.
  describe "with a deck and a lot in its zone (spec 062 AC-5.8a)" do
    def deck = @deck ||= create(:deck, account: user.account, name: "Izzet Tempo")
    def zone_lot = @zone_lot ||= create_lot_in_zone(deck, "main", entry: create(:mtg_printing).entry, quantity: 2)
    def select = page_html.at_css("select[name=location]")
    def bulk_buttons = page_html.css(".c-bulkbar button").map(&:text).uniq

    context "when the account has no place" do
      before { zone_lot }

      it "shows the place line on the tile", :aggregate_failures do
        get collection_path(view: "grid")
        expect(place_lines.sole).to end_with("Main")
      end

      it "shows the Location column and the place on the phone line", :aggregate_failures do
        get collection_path(view: "table")
        expect(page_html.css("thead th").map { it.text.squish }).to include("Location")
        expect(cells.sole).to end_with("Main")
        expect(page_html.at_css(".c-table__sub").text).to include("Main")
      end

      it "shows the place and Move to… in bulk mode", :aggregate_failures do
        get collection_path(bulk: "1")
        expect(cells.sole).to end_with("Main")
        expect(bulk_buttons).to eq([ "Set condition…", "Move to…", "Remove", "Done" ])
      end

      it "shows the filter select, on the grid and the table (spec 065 AC-6.10, decision 3)", :aggregate_failures do
        get collection_path(view: "grid")
        expect(select).to be_present
        get collection_path(view: "table")
        expect(select).to be_present
        get collection_path(bulk: "1")
        expect(select).to be_present
      end
    end

    context "when the account has a place too" do
      before do
        zone_lot
        own(location: blue)
      end

      it "shows the select with places only, the column, Move to… and the place line", :aggregate_failures do
        get collection_path(view: "table")
        expect(select.css("option").map(&:text)).to eq([ "All locations", "No location", "Blue binder" ])
        expect(cells).to contain_exactly("Blue binder", a_string_ending_with("Main"))
        get collection_path(bulk: "1")
        expect(bulk_buttons).to include("Move to…")
        get collection_path(view: "grid")
        expect(place_lines).to contain_exactly("Blue binder", a_string_ending_with("Main"))
      end
    end

    it "shows no column or place line when the account has a deck and no lot in a zone", :aggregate_failures do
      deck
      own
      get collection_path(view: "table")
      expect(page_html.css("thead th").map { it.text.squish }).not_to include("Location")
      get collection_path(view: "grid")
      expect(place_lines).to be_empty
    end

    it "shows the filter select and Move to… when the account has a deck and no lot in a zone (spec 065 AC-6.10, decision 3)", :aggregate_failures do
      deck
      own
      get collection_path(view: "table")
      expect(select).to be_present
      get collection_path(bulk: "1")
      expect(bulk_buttons).to include("Move to…")
    end
  end
end
