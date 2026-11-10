require "rails_helper"

# Spec 059: the refusal page's shortcut into bulk mode (#187).
RSpec.describe "Open a location's lots in bulk mode", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def shortcut_form = page_html.at_css("main form[action='#{location_selection_path(blue)}']")

  # What the browser sends for the bulk table it was just given, with the user touching nothing: the header's state as
  # rendered, each row's shown, baseline and ticked fields as rendered (a disabled field is never sent).
  def untouched_bulk_form(go)
    fields = ->(css) { page_html.css(css).reject { |field| field["disabled"] }.map { |field| field["value"] } }
    { go:, rendered_q: "", rendered_location: blue.id.to_s, all_rendered: page_html.at_css("input[name=all_rendered]")["value"],
      shown_ids: fields.("input[name='shown_ids[]']"), baseline_ids: fields.("input[name='baseline_ids[]']"),
      ticked_ids: page_html.css("tbody input[type=checkbox][checked]").map { |box| box["value"] } }
      .merge(page_html.at_css("thead input[name=all][checked]") ? { all: "1" } : {})
  end

  describe "the button on the refusal page (Story 1)" do
    before do
      own("Card A", location: blue, quantity: 5)
      own("Card B", location: blue, quantity: 7)
    end

    it "is first in the actions row, before Back to locations, with no Remove button (AC-1.1)", :aggregate_failures do
      get new_location_removal_path(blue)

      actions = page_html.at_css("main .c-form__actions")
      expect(actions.element_children.map { |child| child.text.squish }).to eq([ "Move them in bulk mode from “Blue binder”", "Back to locations" ])
      expect(page_html.at_css("main .c-form__actions button").text.squish).to eq("Move them in bulk mode from “Blue binder”")
      expect(page_html.at_css("main .c-form__actions button .c-sr").text).to eq(" from “Blue binder”")
      expect(page_html.at_css("main .c-form__actions button")["class"].split).to include("c-btn", "c-btn--primary")
      expect(page_html.css("main button, main input[type=submit]").map { |control| control.text + control["value"].to_s }.grep(/Remove/)).to be_empty
    end

    it "is on the refusal page a refused DELETE renders (AC-1.2)", :aggregate_failures do
      delete location_path(blue)

      expect(response).to have_http_status(:conflict)
      expect(shortcut_form).to be_present
    end

    it "is not on an empty location's confirmation page (AC-1.3)" do
      get new_location_removal_path(box)

      expect(page_html.css("main form button").map(&:text).map(&:squish)).to eq([ "Remove" ])
    end

    it "is a post form with a button and no field but the token (AC-1.4)", :aggregate_failures do
      get new_location_removal_path(blue)

      expect(shortcut_form["method"]).to eq("post")
      expect(shortcut_form.css("button").size).to eq(1)
      expect(shortcut_form.css("input").map { |field| field["name"] }.uniq - [ "authenticity_token" ]).to be_empty
      expect(page_html.css("main a").map { |link| link["href"] }).not_to include(location_selection_path(blue))
    end

    it "keeps the sentence, the list and Back to locations as they were (AC-1.5)", :aggregate_failures do
      get new_location_removal_path(blue)

      expect(page_html.at_css("main").text.squish).to include("“Blue binder” holds 12 copies in 2 lots. Move them before removing it.")
      expect(page_html.css("#held_lots li").size).to eq(2)
      expect(page_html.css("main a").map(&:text)).to include("Back to locations")
    end

    it "is not on the locations list (decision 5)" do
      get locations_path

      expect(page_html.css("form[action='#{location_selection_path(blue)}']")).to be_empty
    end
  end

  describe "pressing it (Story 2)" do
    # Two lots of 5 and 7 copies in Blue binder, then one of 28 in Long box (one helper: RSpec/MultipleMemoizedHelpers allows 5).
    let!(:held) { [ own("Card A", location: blue, quantity: 5), own("Card B", location: blue, quantity: 7), own("Card C", location: box, quantity: 28) ] }

    it "answers 303 to the bulk table under the location, with every lot selected (AC-2.1, AC-2.2)", :aggregate_failures do
      post location_selection_path(blue)

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path(bulk: 1, location: blue.id))
      follow_redirect!
      expect(page_html.css("tbody tr").map { |row| row.at_css("a").text }).to contain_exactly("Card A", "Card B")
      expect(page_html.css("tbody tr[aria-selected=true]").size).to eq(2)
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("All 12 items selected")
      expect(page_html.at_css("thead input[name=all]")["checked"]).to be_present
      expect(page_html.at_css(".c-filterbar__count").text.squish).to eq("12 of 40 items")
      expect(page_html.at_css("select[name=location] option[selected]").text).to eq("Blue binder")
    end

    it "offers the bulk actions and opens Move to… for every copy, without the location as a destination (AC-2.3)", :aggregate_failures do
      post location_selection_path(blue)
      get collection_path(bulk: 1, location: blue.id)
      expect(page_html.css(".c-bulkbar__extra button").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])

      patch collection_selection_path, params: untouched_bulk_form("move") # what the stored selection alone gives the browser
      follow_redirect!
      expect(page_html.at_css("h1").text).to eq("Move 12 items")
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Long box" ])
    end

    it "replaces the stored selection, its ticks included (AC-2.4)", :aggregate_failures do
      post collection_selection_path, params: { q: "card", location: box.id, sort: "price", dir: "desc" }
      patch collection_selection_path, params: { go: "filter", q: "card", location: box.id, rendered_q: "card", rendered_location: box.id.to_s,
        sort: "price", dir: "desc", all_rendered: "0", shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      selection = BulkSelection.find_by!(account:)
      expect(selection.marks.count).to eq(1)

      post location_selection_path(blue)

      selection.reload
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.all_matching, selection.marks.count ]).to eq([ "", blue.id.to_s, CollectionTable::Sort.parse(nil, nil).key, true, 0 ])
      expect(BulkSelection.where(account:).count).to eq(1)
    end

    it "leaves an undoable bulk removal undoable (AC-2.5)", :aggregate_failures do
      post collection_selection_path
      patch collection_selection_path, params: { go: "remove", rendered_q: "", rendered_location: "", all_rendered: "0",
        shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      post collection_bulk_removals_path
      undoable = BulkRemoval.where(account:).undoable.last
      expect(undoable).to be_present

      post location_selection_path(blue)

      expect(undoable.reload).to be_undoable
    end

    it "lands on the empty-filter table when the location was emptied meanwhile (AC-2.6)", :aggregate_failures do
      account.lots.where(location: blue).delete_all
      post location_selection_path(blue)

      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      follow_redirect!
      expect(page_html.at_css("main").text.squish).to include("No cards in your collection are in “Blue binder”.")
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("0 of 0 selected")
      expect(page_html.css("thead input[type=checkbox]")).to be_empty
    end

    it "lands on the empty collection's page when no lot is left at all (AC-2.6)", :aggregate_failures do
      account.lots.delete_all
      post location_selection_path(blue)
      follow_redirect!

      expect(response.body).to include("No cards in your collection yet.")
      expect(page_html.css(".c-bulkbar")).to be_empty
    end

    it "costs a number of statements independent of the lots it selects (Performance NFR)" do
      post location_selection_path(blue) # the selection exists and holds these values, so both measured calls do the same writes
      few = count_queries { post location_selection_path(blue) }
      30.times { |n| own("Extra #{n}", location: blue) }

      expect(count_queries { post location_selection_path(blue) }).to eq(few)
    end

    it "reads a location removed after the redirect as all locations, nothing selected (AC-2.6a)", :aggregate_failures do
      post location_selection_path(blue)
      account.lots.where(location: blue).delete_all
      blue.destroy!
      get collection_path(bulk: 1, location: blue.id)

      expect(response).to have_http_status(:ok)
      expect(page_html.css("tbody tr").size).to eq(1)
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
    end

    it "returns to the saved view under the location on Done (AC-2.7)", :aggregate_failures do
      post location_selection_path(blue)
      patch collection_selection_path, params: { go: "done", rendered_q: "", rendered_location: blue.id.to_s }

      expect(response).to redirect_to(collection_path(location: blue.id))
      expect(BulkSelection.where(account:)).to be_empty
    end
  end

  describe "only my locations (Story 4)" do
    let!(:foreign) { create(:location, account: create(:user).account, name: "Their binder") }

    it "answers 404 for another account's location and changes nothing (AC-4.1)", :aggregate_failures do
      post collection_selection_path
      stored = BulkSelection.where(account:).map(&:attributes)

      post location_selection_path(foreign)

      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:).map(&:attributes)).to eq(stored)
      expect(BulkSelection.where(account: foreign.account)).to be_empty
    end

    it "answers 404 for a location that doesn't exist (AC-4.2)" do
      post location_selection_path(blue.id + 1000)

      expect(response).to have_http_status(:not_found)
    end

    it "ignores a name filter, location, sort, account or user value in the request (AC-4.3)", :aggregate_failures do
      own("Card A", location: blue)
      post location_selection_path(blue), params: { q: "zzz", location: box.id, sort: "price", dir: "desc", account_id: foreign.account.id, user_id: 1, admin: "1" }

      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      selection = BulkSelection.find_by!(account:)
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.account_id ]).to eq([ "", blue.id.to_s, CollectionTable::Sort.parse(nil, nil).key, account.id ])
    end

    it "sends a signed-out visitor to sign-in and creates nothing (AC-4.4)", :aggregate_failures do
      delete session_path
      post location_selection_path(blue)

      expect(response).to redirect_to(new_session_path)
      expect(BulkSelection.where(account:)).to be_empty
    end

    it "answers no GET, prefetch-marked or not, and changes nothing (AC-4.5)", :aggregate_failures do
      get "/locations/#{blue.id}/selection"
      expect(response).to have_http_status(:not_found)

      get "/locations/#{blue.id}/selection", headers: { "Sec-Purpose" => "prefetch" }
      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:)).to be_empty
    end
  end
end
