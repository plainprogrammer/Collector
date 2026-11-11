require "rails_helper"

RSpec.describe "The collection's Location select", type: :request do # spec 037 Phase 3
  let(:user) { create(:user) }
  let(:blue) { create(:location, account:, name: "Blue binder") }

  before { sign_in_as(user) }

  def account = user.account
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def select = page_html.at_css("select[name=location]")
  def options = select.css("option").map { [ it.text, it["value"] ] }
  def chosen = select.at_css("option[selected]")&.[]("value") || ""
  def empty_text = page_html.at_css(".c-empty")&.text&.squish
  def hidden(form_id) = page_html.css("##{form_id} input[type=hidden]").to_h { [ it["name"], it["value"] ] }

  def start_bulk(**params)
    post collection_selection_path, params: params.compact
    follow_redirect!
  end

  describe "the control (AC-1.1, AC-1.5, AC-6.3)" do
    it "lists all, none, then the locations in the locations page's order, in the filter bar's GET form", :aggregate_failures do
      create(:location, account:, name: "long box")
      blue
      own
      get collection_path
      expect(options).to eq([ [ "All locations", "" ], [ "No location", "none" ], [ "Blue binder", blue.id.to_s ], [ "long box", account.locations.find_by(name: "long box").id.to_s ] ])
      expect(chosen).to eq("")
      label = select.parent
      expect([ label.name, label["class"], label.at_css(".c-sr").text ]).to eq([ "label", "c-select c-select--wide", "Location" ])
      expect(select["form"]).to be_nil
      filters = select.ancestors(".c-filterbar__filters").first
      expect(filters.ancestors("form").first["method"]).to eq("get")
      button = filters.css("input[type=submit], button").last
      expect([ button["value"] || button.text, button["name"] ]).to eq([ "Filter", nil ])
    end

    it "shows the chosen location, in both views", :aggregate_failures do
      own(location: blue)
      %w[grid table].each do |view|
        get collection_path(view:, location: blue.id)
        expect(chosen).to eq(blue.id.to_s)
      end
      get collection_path(location: "none")
      expect(chosen).to eq("none")
    end

    it "carries the wide modifier in bulk mode too (AC-4.6)" do
      own
      blue
      start_bulk
      expect(select.parent["class"]).to eq("c-select c-select--wide")
    end

    it "is not shown while the account has no location, in either mode (AC-6.1)", :aggregate_failures do
      own
      get collection_path(location: "none")
      expect(select).to be_nil
      start_bulk
      expect([ select, page_html.at_css("button[value=filter]")["class"] ]).to eq([ nil, "c-sr" ])
    end

    it "escapes a location's name (AC-6.6)", :aggregate_failures do
      odd = create(:location, account:, name: %(<b>&"x))
      own
      get collection_path(location: odd.id)
      expect(options.last).to eq([ %(<b>&"x), odd.id.to_s ])
      expect(response.body).not_to include("<b>&")
      expect(empty_text).to eq(%(No cards in your collection are in “<b>&"x”.))
    end
  end

  describe "the empty sentences (AC-1.6, AC-2.2, AC-3.2)" do
    before { own("Opt", location: blue) }

    it "names the location, none, and the query with either", :aggregate_failures do
      empty = create(:location, account:, name: "Empty box")
      expectations = {
        { location: empty.id } => "No cards in your collection are in “Empty box”.",
        { location: "none" } => "No cards in your collection are without a location.",
        { location: blue.id, q: "bolt" } => %(No cards in your collection match "bolt" in “Blue binder”.),
        { location: "none", q: "bolt" } => %(No cards in your collection match "bolt" without a location.),
        { q: "bolt" } => %(No cards in your collection match "bolt".)
      }
      expectations.each do |params, sentence|
        %w[grid table].each do |view|
          get collection_path(view:, **params)
          expect([ empty_text, page_html.at_css(".c-results__meta").text.squish, page_html.css(".c-grid, .c-table, .c-pager").size ])
            .to eq([ sentence, "0 of 1 item", 0 ])
        end
      end
    end

    it "shows the sentence and 0 of 0 selected in bulk mode (AC-5.4)", :aggregate_failures do
      start_bulk(location: "none")
      expect([ empty_text, page_html.at_css(".c-bulkbar__count").text, page_html.at_css("thead input[name=all]") ])
        .to eq([ "No cards in your collection are without a location.", "0 of 0 selected", nil ])
    end
  end

  describe "links and forms keep the filter (AC-3.3, AC-4.1, AC-5.6)" do
    it "carries the location in pagers, sort headers, the view switch, Edit many and row menus", :aggregate_failures do
      stub_const("CollectionGrid::PER_PAGE", 1)
      stub_const("CollectionTable::PER_PAGE", 1)
      own("Lightning Bolt", location: blue)
      own("Opt", location: blue)
      get collection_path(view: "grid", location: blue.id)
      expect(page_html.at_css(".c-pager a")["href"]).to eq(collection_path(location: blue.id, page: 2))
      expect([ hidden("view-switch")["location"], hidden("edit-many")["location"] ]).to eq([ blue.id.to_s, blue.id.to_s ])
      get collection_path(view: "table", location: blue.id)
      expect(page_html.at_css(".c-pager a")["href"]).to eq(collection_path(view: "table", location: blue.id, page: 2))
      expect(page_html.at_css("th a.c-table__sort")["href"]).to include("location=#{blue.id}")
      expect(page_html.css("tbody .c-menu__item").map { it["href"] }).to all(include(CGI.escape("location=#{blue.id}")))
    end

    it "leaves the location out of the forms for all", :aggregate_failures do
      own
      blue
      get collection_path
      expect([ hidden("view-switch").key?("location"), hidden("edit-many").key?("location") ]).to eq([ false, false ])
    end

    it "keeps the card page listing every lot of the printing (AC-4.3)", :aggregate_failures do
      lot = own(location: blue)
      create(:lot, account:, entry: lot.entry, location: create(:location, account:, name: "Long box"), finish: "foil")
      get catalog_entry_path(lot.entry, from: "collection")
      expect(page_html.css("#copies tbody tr").size).to eq(2)
    end
  end

  describe "bulk mode (AC-5.1, AC-5.6, decision 6)" do
    it "joins the select to the bulk form, shows the choice and makes the default Filter button visible", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      own("Lightning Bolt", location: blue, quantity: 2)
      own("Opt", location: blue)
      start_bulk(location: blue.id)
      expect([ select["form"], chosen ]).to eq([ "bulk", blue.id.to_s ])
      expect(page_html.at_css(".c-bulkbar__count").text).to eq("0 of 3 selected")
      submits = page_html.css("button[form=bulk][type=submit], #bulk button[type=submit]")
      expect([ submits.first["value"], submits.first.text, submits.first["class"], submits.first["tabindex"] ])
        .to eq([ "filter", "Filter", "c-btn c-btn--secondary c-btn--sm", nil ])
      expect(submits.first.ancestors(".c-filterbar__filters")).not_to be_empty
      expect(hidden("bulk")["rendered_location"]).to eq(blue.id.to_s)
      expect(page_html.at_css(".c-pager button")["value"]).to eq(collection_path(bulk: 1, location: blue.id, page: 2))
      expect(page_html.at_css("th button.c-table__sort")["value"]).to include("location=#{blue.id}")
    end

    it "keeps the location on the confirm page's Cancel and Back, and counts the filtered table's pages (AC-5.6, AC-1.4)", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      lots = [ own("Lightning Bolt", location: blue), own("Opt", location: blue) ]
      own("Shock")
      start_bulk(location: blue.id)
      expect(page_html.at_css(".c-pager__position").text).to eq("Page 1 of 2")
      patch collection_selection_path, params: { go: "remove", rendered_location: blue.id.to_s, all_rendered: "0", shown_ids: [ lots.first.id ], ticked_ids: [ lots.first.id ] }
      follow_redirect!
      back = collection_path(bulk: 1, location: blue.id)
      expect([ page_html.at_css(".c-confirm a.c-btn--secondary")["href"], page_html.at_css('header a[aria-label="Back"]')["href"] ]).to eq([ back, back ])
    end

    it "sends the confirm page for a selection whose location is gone back to the bulk table (AC-5.5)", :aggregate_failures do
      gone = create(:location, account:)
      own(location: blue)
      start_bulk(location: gone.id)
      gone.destroy!
      get new_collection_bulk_removal_path
      expect(response).to redirect_to(collection_path(bulk: 1, location: gone.id))
      expect(flash[:alert]).to eq(BulkSelection::NOTHING_SELECTED)
    end

    it "re-renders a refusal under the location, with the select and sentence (AC-5.6)", :aggregate_failures do
      own(location: blue)
      start_bulk(location: blue.id)
      patch collection_selection_path, params: { go: "remove", rendered_location: blue.id.to_s, location: blue.id.to_s, all_rendered: "0" }
      expect([ response.status, chosen, hidden("bulk")["rendered_location"] ]).to eq([ 422, blue.id.to_s, blue.id.to_s ])
    end

    it "shows all locations on the refusal for a removed location (AC-5.8)", :aggregate_failures do
      own
      gone = create(:location, account:)
      blue
      start_bulk(location: gone.id)
      gone.destroy!
      patch collection_selection_path, params: { go: "remove", rendered_location: gone.id.to_s, all_rendered: "0", all: "1" }
      expect([ response.status, chosen, hidden("bulk")["rendered_location"] ]).to eq([ 422, "", "" ])
    end
  end

  # Spec 062 D6, AC-5.1, AC-5.2: the select lists places only, and the value of a zone or a deck is "all".
  describe "with a deck (spec 062)" do
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")

    it "lists all, none, then the places only, never a deck or a zone (AC-5.1)", :aggregate_failures do
      deck
      create(:location, account:, name: "Long box")
      own(location: blue)
      get collection_path
      expect(options).to eq([ [ "All locations", "" ], [ "No location", "none" ], [ "Blue binder", blue.id.to_s ], [ "Long box", account.locations.find_by(name: "Long box").id.to_s ] ])
    end

    it "reads a zone's id and a deck's id as all on the bulk page's shown filter and its hidden value (AC-5.2)", :aggregate_failures do
      own("Placed", location: blue)
      create_lot_in_zone(deck, "main", quantity: 2)
      [ deck.zone("main").id, deck.location_id ].each do |id|
        start_bulk(location: id)
        expect([ chosen, hidden("bulk")["rendered_location"] ]).to eq([ "", "" ]), id.to_s
      end
    end
  end
end
