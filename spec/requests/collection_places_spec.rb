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
end
