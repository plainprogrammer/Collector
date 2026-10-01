require "rails_helper"

RSpec.describe "Bulk mode", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def count_text = page_html.at_css(".c-bulkbar__count").text
  def ticked = page_html.css("tbody input[name='ticked_ids[]'][checked]").map { |box| box["value"].to_i }

  def start_bulk(**params)
    post collection_selection_path, params: params.compact
    follow_redirect!
  end

  def submit_bulk(go:, shown: [], ticked: [], all: false, all_rendered: false, q: "", rendered_q: q, sort: nil, dir: nil, page: nil)
    params = { go:, shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id), q:, rendered_q:, sort:, dir:, page:,
      all_rendered: all_rendered ? "1" : "0" }
    params[:all] = "1" if all
    patch collection_selection_path, params: params.compact
  end

  describe "entering" do
    it "opens the table in bulk mode with the same filter and sort and nothing selected", :aggregate_failures do
      bolt = own("Lightning Bolt", quantity: 3)
      own("Opt")
      post collection_selection_path, params: { q: "bolt", sort: "price", dir: "desc" }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt", sort: "price", dir: "desc"))
      follow_redirect!
      expect(page_html.css("tbody input[name='ticked_ids[]']").map { |box| [ box["value"].to_i, box["checked"] ] }).to eq([ [ bolt.id, nil ] ])
      expect(page_html.at_css("thead input[name=all]")["aria-label"]).to eq("Select all")
      expect(count_text).to eq("0 of 3 selected")
      expect(page_html.css(".c-bulkbar__extra button").map { |button| [ button.text, button["value"], button["class"] ] }).to eq([
        [ "Set condition…", "set_condition", "c-btn c-btn--secondary c-btn--sm" ], [ "Remove", "remove", "c-btn c-btn--danger c-btn--sm" ]
      ])
      expect(page_html.css(".c-bulkbar__more .c-menu__item").map { |button| button["value"] }).to eq(%w[set_condition remove])
      expect(page_html.at_css(".c-bulkbar > button[value=done]")["class"]).to eq("c-btn c-btn--primary c-btn--sm")
      expect(page_html.css("td.c-table__actions")).to be_empty
    end

    it "clears an earlier selection" do
      lot = own
      start_bulk
      submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
      start_bulk
      expect(count_text).to eq("0 of 1 selected")
    end

    it "shows the table in bulk mode even when the URL names the grid" do
      own
      get collection_path(bulk: 1, view: "grid")
      expect(response.body).to include('<table class="c-table">')
    end

    it "shows the empty state, with no bulk bar, on an empty collection" do
      get collection_path(bulk: 1)
      expect([ response.body.include?("No cards in your collection yet."), response.body.include?("c-bulkbar") ]).to eq([ true, false ])
    end
  end

  describe "the bulk page" do
    it "makes the view switch inert and keeps it out of the bulk form", :aggregate_failures do
      own
      start_bulk
      seg = page_html.at_css(".c-seg")
      expect(seg.css("button").map { |b| [ b.text.strip, b["type"], b["aria-pressed"], b.key?("disabled"), b["form"] ] }).to eq([
        [ "Grid", "button", "false", true, nil ], [ "Table", "button", "true", false, nil ]
      ])
      expect(seg.ancestors("form")).to be_empty
    end

    it "makes Filter the form's default submit, and keeps url-sync off it", :aggregate_failures do
      own
      start_bulk
      submitters = page_html.css("button[form=bulk], form#bulk button[type=submit]")
      expect([ submitters.first["value"], submitters.first["tabindex"] ]).to eq([ "filter", "-1" ])
      expect(page_html.at_css("input[name=q]")["form"]).to eq("bulk")
      expect(page_html.at_css("form#bulk")["data-controller"]).to be_nil
    end

    it "sorts with buttons of the bulk form that keep bulk mode", :aggregate_failures do
      own
      start_bulk
      name = page_html.css("thead th").find { |th| th.text.strip == "Name" }
      expect([ name.at_css("button")["name"], name.at_css("button")["value"] ]).to eq([ "go", collection_path(bulk: 1, sort: "name", dir: "desc") ])
    end

    it "has no checkboxes or bulk bar outside bulk mode" do
      own
      get collection_path(view: "table")
      expect([ page_html.css("input[type=checkbox]").size, page_html.css(".c-bulkbar").size ]).to eq([ 0, 0 ])
    end

    it "counts nothing when the filter matches nothing", :aggregate_failures do
      own
      start_bulk(q: "zzz")
      expect(response.body).to include(%(No cards in your collection match "zzz".))
      expect([ count_text, page_html.css("thead input[name=all]").size ]).to eq([ "0 of 0 selected", 0 ])
    end
  end

  describe "selecting" do
    it "counts the selected copies against the filter's, with digit grouping", :aggregate_failures do
      big = own("Lightning Bolt", quantity: 1_200)
      small = own("Opt", quantity: 3)
      start_bulk
      submit_bulk(go: "filter", shown: [ big, small ], ticked: [ big ])
      follow_redirect!
      expect([ count_text, ticked ]).to eq([ "1,200 of 1,203 selected", [ big.id ] ])
      expect(page_html.at_css("tbody tr:has(input[value='#{big.id}'])")["aria-selected"]).to eq("true")
    end

    it "keeps ticks across pages and after a reload", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      first = own("Card A")
      second = own("Card B", quantity: 2)
      start_bulk
      submit_bulk(go: collection_path(bulk: 1, page: 2), shown: [ first ], ticked: [ first ], page: 1)
      expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
      follow_redirect!
      expect([ count_text, ticked ]).to eq([ "1 of 3 selected", [] ])
      submit_bulk(go: collection_path(bulk: 1), shown: [ second ], ticked: [ second ], page: 2)
      follow_redirect!
      expect([ count_text, ticked ]).to eq([ "3 of 3 selected", [ first.id ] ])
      get collection_path(bulk: 1)
      expect(ticked).to eq([ first.id ])
    end

    context "with every matching lot selected from the header" do
      let!(:first) { own("Bolt A", quantity: 2) }
      let!(:second) { own("Bolt B", quantity: 3) }

      before do
        stub_const("CollectionTable::PER_PAGE", 1)
        own("Opt")
        start_bulk(q: "bolt")
        submit_bulk(go: "filter", q: "bolt", shown: [ first ], all: true)
        follow_redirect!
      end

      it "selects lots on every page and says so" do
        expect([ count_text, ticked, page_html.at_css("thead input[name=all]").key?("checked") ]).to eq([ "All 5 items selected", [ first.id ], true ])
      end

      it "keeps an untick as an exception across pages", :aggregate_failures do
        submit_bulk(go: "filter", q: "bolt", shown: [ first ], all: true, all_rendered: true)
        follow_redirect!
        expect([ count_text, ticked, page_html.at_css("input[name=all_rendered]")["value"] ]).to eq([ "3 of 5 selected", [], "1" ])
        submit_bulk(go: collection_path(bulk: 1, q: "bolt", page: 2), q: "bolt", shown: [ first ], all: true, all_rendered: true)
        follow_redirect!
        expect(ticked).to eq([ second.id ])
      end

      it "clears everything when the header is unticked, whatever the rows say" do
        submit_bulk(go: "filter", q: "bolt", shown: [ first ], ticked: [ first ], all_rendered: true)
        follow_redirect!
        expect(count_text).to eq("0 of 5 selected")
      end
    end

    it "clears the selection when the filter or sort changes", :aggregate_failures do
      lot = own
      start_bulk
      submit_bulk(go: "filter", q: "light", rendered_q: "", shown: [ lot ], ticked: [ lot ])
      expect(response).to redirect_to(collection_path(bulk: 1, q: "light"))
      follow_redirect!
      expect(count_text).to eq("0 of 1 selected")
      submit_bulk(go: "filter", q: "light", shown: [ lot ], ticked: [ lot ])
      submit_bulk(go: collection_path(bulk: 1, q: "light", sort: "price", dir: "asc"), q: "light", shown: [ lot ], ticked: [ lot ])
      follow_redirect!
      expect(count_text).to eq("0 of 1 selected")
    end

    it "reloads the same page for an unchanged filter, keeping the ticks", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      own("Card A")
      second = own("Card B")
      start_bulk
      submit_bulk(go: "filter", shown: [ second ], ticked: [ second ], page: 2)
      expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
    end

    it "never changes the selection on a page load, and shows a selection from another filter as nothing", :aggregate_failures do
      lot = own
      start_bulk
      submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
      get collection_path(bulk: 1, q: "bolt")
      expect(count_text).to eq("0 of 1 selected")
      get collection_path(bulk: 1)
      expect(ticked).to eq([ lot.id ])
    end

    it "treats malformed id lists as no ticks" do
      own
      start_bulk
      patch collection_selection_path, params: { go: "filter", q: "", rendered_q: "", all_rendered: "0", shown_ids: { "a" => "1" }, ticked_ids: { "a" => "1" } }
      expect(response).to have_http_status(:see_other)
    end

    it "ignores another account's lots and account or user values", :aggregate_failures do
      mine = own
      theirs = owned_printing(account: create(:user).account)
      start_bulk
      patch collection_selection_path, params: { go: "filter", q: "", rendered_q: "", all_rendered: "0",
        shown_ids: [ mine.id, theirs.id ], ticked_ids: [ mine.id, theirs.id ], account_id: theirs.account_id, user_id: 1 }
      follow_redirect!
      expect(count_text).to eq("1 of 1 selected")
      expect(BulkSelection.sole.account).to eq(user.account)
    end
  end

  describe "actions and Done" do
    it "refuses an action with nothing selected, re-rendering the bulk table", :aggregate_failures do
      lot = own
      start_bulk
      submit_bulk(go: "remove", shown: [ lot ])
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css(".c-status__message--alert").text).to eq("Select at least one item.")
      expect(page_html.at_css("form#bulk")).to be_present
    end

    it "refuses an action whose ticks are all gone or not the account's" do
      theirs = owned_printing(account: create(:user).account)
      own
      start_bulk
      submit_bulk(go: "set_condition", shown: [ theirs ], ticked: [ theirs ])
      expect(page_html.at_css(".c-status__message--alert").text).to eq("None of the selected items are in your collection any more.")
    end

    it "goes to the action's page with the page number", :aggregate_failures do
      lot = own
      start_bulk
      submit_bulk(go: "set_condition", shown: [ lot ], ticked: [ lot ], page: 1)
      expect(response).to redirect_to(new_collection_condition_change_path(page: 1))
      submit_bulk(go: "remove", shown: [ lot ], ticked: [ lot ], page: 1)
      expect(response).to redirect_to(new_collection_bulk_removal_path(page: 1))
    end

    it "leaves bulk mode on Done for the saved view, with the filter and sort, discarding the selection", :aggregate_failures do
      lot = own
      user.update!(collection_view: "grid")
      start_bulk(q: "bolt", sort: "price", dir: "asc")
      submit_bulk(go: "done", q: "bolt", sort: "price", dir: "asc", shown: [ lot ], ticked: [ lot ])
      expect(response).to redirect_to(collection_path(q: "bolt", sort: "price", dir: "asc"))
      expect([ BulkSelection.count, user.reload.collection_view ]).to eq([ 0, "grid" ])
      follow_redirect!
      expect(response.body).to include('class="c-grid"')
    end

    it "keeps the selection when bulk mode is left any other way, until the next Edit many", :aggregate_failures do
      lot = own
      start_bulk
      submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
      get collection_path
      get collection_path(bulk: 1)
      expect(ticked).to eq([ lot.id ])
      start_bulk
      expect(ticked).to eq([])
    end
  end
end
