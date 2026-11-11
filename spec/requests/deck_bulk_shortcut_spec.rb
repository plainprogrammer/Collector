require "rails_helper"

# Spec 067: the deck refusal page's shortcut into bulk mode (#302).
RSpec.describe "Open a deck's lots in bulk mode", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def shortcut_form = page_html.at_css("main form[action='#{deck_selection_path(deck)}']")
  def deck_value = CollectionFilter::Place.deck_value(deck.location_id)

  # What the browser sends for the bulk table it was just given, with the user touching nothing: the header's state as
  # rendered, each row's shown, baseline and ticked fields as rendered (a disabled field is never sent).
  def untouched_bulk_form(go)
    fields = ->(css) { page_html.css(css).reject { |field| field["disabled"] }.map { |field| field["value"] } }
    { go:, rendered_q: "", rendered_location: deck_value, all_rendered: page_html.at_css("input[name=all_rendered]")["value"],
      shown_ids: fields.("input[name='shown_ids[]']"), baseline_ids: fields.("input[name='baseline_ids[]']"),
      ticked_ids: page_html.css("tbody input[type=checkbox][checked]").map { |box| box["value"] } }
      .merge(page_html.at_css("thead input[name=all][checked]") ? { all: "1" } : {})
  end

  describe "the button on the refusal page (Story 1)" do
    before do
      own("Card A", location: deck.zone("main"), quantity: 5)
      own("Card B", location: deck.zone("sideboard"), quantity: 7)
    end

    it "is first in the actions row, before Back to decks, with no Remove button (AC-1.1)", :aggregate_failures do
      get new_deck_removal_path(deck)

      actions = page_html.at_css("main .c-form__actions")
      button = page_html.at_css("main .c-form__actions button")
      expect(actions.element_children.map { |child| child.text.squish }).to eq([ "Move them in bulk mode from “Izzet Tempo”", "Back to decks" ])
      expect(button.at_css(".c-sr").text).to eq(" from “Izzet Tempo”")
      expect(button["class"].split).to include("c-btn", "c-btn--primary")
      expect(page_html.css("main button, main input[type=submit]").map { |control| control.text + control["value"].to_s }.grep(/Remove/)).to be_empty
    end

    it "is on the refusal page a refused DELETE renders (AC-1.2)", :aggregate_failures do
      delete deck_path(deck)

      expect(response).to have_http_status(:conflict)
      expect(shortcut_form).to be_present
    end

    it "is not on an empty deck's confirmation page (AC-1.3)" do
      empty = create(:deck, account:, name: "Krenko")
      get new_deck_removal_path(empty)

      expect(page_html.css("main form button").map(&:text).map(&:squish)).to eq([ "Remove" ])
    end

    it "is a post form with a button and no field but the token (AC-1.4)", :aggregate_failures do
      get new_deck_removal_path(deck)

      expect(shortcut_form["method"]).to eq("post")
      expect(shortcut_form.css("button").size).to eq(1)
      expect(shortcut_form.css("button").first.text.squish).to eq("Move them in bulk mode from “Izzet Tempo”")
      expect(shortcut_form.css("input").map { |field| field["name"] }.uniq - [ "authenticity_token" ]).to be_empty
      expect(page_html.css("main a").map { |link| link["href"] }).not_to include(deck_selection_path(deck))
    end

    it "keeps the sentence, the list and Back to decks as they were (AC-1.5)", :aggregate_failures do
      get new_deck_removal_path(deck)

      expect(page_html.at_css("main").text.squish).to include("“Izzet Tempo” holds 12 copies in 2 lots. Move them before removing it.")
      expect(page_html.css("#held_lots li").size).to eq(2)
      expect(page_html.css("#held_lots li .c-decks__zone").map(&:text)).to contain_exactly("Izzet Tempo › Main", "Izzet Tempo › Sideboard")
      expect(page_html.css("main a").map(&:text)).to include("Back to decks")
    end

    it "leaves a place's refusal page as spec 059 defines it (AC-1.6)", :aggregate_failures do
      own("Card Z", location: box)
      get new_location_removal_path(box)

      expect(page_html.css("main form").map { |form| form["action"] }).to eq([ location_selection_path(box) ])
    end

    it "is not on the Decks page (decision 4)" do
      get decks_path

      expect(page_html.css("form[action='#{deck_selection_path(deck)}']")).to be_empty
    end
  end

  describe "pressing it (Story 2)" do
    # 5 + 7 copies in the deck's two zones, then 28 in Long box: 40 in the collection, 12 in the deck.
    let!(:held) do
      [ own("Card A", location: deck.zone("main"), quantity: 5), own("Card B", location: deck.zone("sideboard"), quantity: 7),
        own("Card C", location: box, quantity: 28) ]
    end

    it "answers 303 to the bulk table under the deck, with every lot selected (AC-2.1, AC-2.2)", :aggregate_failures do
      post deck_selection_path(deck)

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path(bulk: 1, location: deck_value))
      expect(response.location).to include("location=deck%3A#{deck.location_id}")
      follow_redirect!
      expect(page_html.css("tbody tr").map { |row| row.at_css("a").text }).to contain_exactly("Card A", "Card B")
      expect(page_html.css("tbody tr[aria-selected=true]").size).to eq(2)
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("All 12 items selected")
      expect(page_html.at_css("thead input[name=all]")["checked"]).to be_present
      expect(page_html.at_css(".c-filterbar__count").text.squish).to eq("12 of 40 items")
      expect(page_html.at_css("select[name=location] option[selected]").text).to eq("Izzet Tempo (all zones)")
      expect(page_html.css("tbody tr").map { |row| row.text.squish }.join(" ")).to include("Izzet Tempo › Main").and include("Izzet Tempo › Sideboard")
    end

    it "offers the bulk actions and opens Move to… for every copy, with no destination left out (AC-2.3)", :aggregate_failures do
      post deck_selection_path(deck)
      get collection_path(bulk: 1, location: deck_value)
      expect(page_html.css(".c-bulkbar__extra button").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])

      patch collection_selection_path, params: untouched_bulk_form("move") # what the stored selection alone gives the browser
      follow_redirect!
      expect(page_html.at_css("h1").text).to eq("Move 12 items")
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Long box", *deck.zones.map { "Izzet Tempo › #{it.name}" } ])
    end

    it "replaces the stored selection, its ticks included (AC-2.4)", :aggregate_failures do
      post collection_selection_path, params: { q: "card", location: box.id, sort: "price", dir: "desc" }
      patch collection_selection_path, params: { go: "filter", q: "card", location: box.id, rendered_q: "card", rendered_location: box.id.to_s,
        sort: "price", dir: "desc", all_rendered: "0", shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      selection = BulkSelection.find_by!(account:)
      expect(selection.marks.count).to eq(1)

      post deck_selection_path(deck)

      selection.reload
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.all_matching, selection.marks.count ]).to eq([ "", deck_value, CollectionTable::Sort.parse(nil, nil).key, true, 0 ])
      expect(BulkSelection.where(account:).count).to eq(1)
    end

    it "leaves an undoable bulk removal undoable (AC-2.5)", :aggregate_failures do
      post collection_selection_path
      patch collection_selection_path, params: { go: "remove", rendered_q: "", rendered_location: "", all_rendered: "0",
        shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      post collection_bulk_removals_path
      undoable = BulkRemoval.where(account:).undoable.last
      expect(undoable).to be_present

      post deck_selection_path(deck)

      expect(undoable.reload).to be_undoable
    end

    it "lands on the empty-filter table when the deck was emptied meanwhile (AC-2.6)", :aggregate_failures do
      account.lots.where(location: deck.zones).delete_all
      post deck_selection_path(deck)

      expect(response).to redirect_to(collection_path(bulk: 1, location: deck_value))
      follow_redirect!
      expect(page_html.at_css("main").text.squish).to include("No cards in your collection are in “Izzet Tempo”.")
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("0 of 0 selected")
      expect(page_html.css("thead input[type=checkbox]")).to be_empty
    end

    it "lands on the empty collection's page when no lot is left at all (AC-2.6)", :aggregate_failures do
      account.lots.delete_all
      post deck_selection_path(deck)
      follow_redirect!

      expect(response.body).to include("No cards in your collection yet.")
      expect(page_html.css(".c-bulkbar")).to be_empty
    end

    it "costs a number of statements independent of the lots it selects (Performance NFR)" do
      post deck_selection_path(deck) # the selection exists and holds these values, so both measured calls do the same writes
      few = count_queries { post deck_selection_path(deck) }
      30.times { |n| own("Extra #{n}", location: deck.zone("main")) }

      expect(count_queries { post deck_selection_path(deck) }).to eq(few)
    end

    it "reads a deck removed after the redirect as all locations, nothing selected (AC-2.7)", :aggregate_failures do
      post deck_selection_path(deck)
      account.lots.where(location: deck.zones).delete_all
      deck.remove!
      get collection_path(bulk: 1, location: deck_value)

      expect(response).to have_http_status(:ok)
      expect(page_html.css("tbody tr").size).to eq(1)
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
    end

    it "returns to the saved view under the deck on Done (AC-2.8)", :aggregate_failures do
      post deck_selection_path(deck)
      patch collection_selection_path, params: { go: "done", rendered_q: "", rendered_location: deck_value }

      expect(response).to redirect_to(collection_path(location: deck_value))
      expect(BulkSelection.where(account:)).to be_empty
    end

    describe "using the bulk actions on it (AC-2.9)" do
      it "moves exactly the deck's lots with Move to…", :aggregate_failures do
        post deck_selection_path(deck)
        get collection_path(bulk: 1, location: deck_value)
        patch collection_selection_path, params: untouched_bulk_form("move")
        post collection_move_path, params: { to: box.id }

        expect(response).to have_http_status(:see_other)
        expect(held.first(2).map { it.reload.location }).to all(eq(box))
        expect(held.last.reload).to have_attributes(location: box, quantity: 28)
        expect(account.lots.sum(:quantity)).to eq(40)
      end

      it "sets the condition of exactly the deck's lots, each staying in its zone", :aggregate_failures do
        post deck_selection_path(deck)
        get collection_path(bulk: 1, location: deck_value)
        patch collection_selection_path, params: untouched_bulk_form("set_condition")
        post collection_condition_change_path, params: { condition: "lightly_played" }

        expect(held.first.reload).to have_attributes(condition: "lightly_played", location: deck.zone("main"))
        expect(held.second.reload).to have_attributes(condition: "lightly_played", location: deck.zone("sideboard"))
        expect(held.last.reload.condition).not_to eq("lightly_played")
      end

      it "removes exactly the deck's lots with Remove", :aggregate_failures do
        post deck_selection_path(deck)
        get collection_path(bulk: 1, location: deck_value)
        patch collection_selection_path, params: untouched_bulk_form("remove")
        post collection_bulk_removals_path

        expect(account.lots.pluck(:id)).to eq([ held.last.id ])
      end
    end
  end

  describe "only my decks (Story 4)" do
    let!(:foreign) { create(:deck, account: create(:user).account, name: "Their deck") }

    it "answers 404 for another account's deck and changes nothing (AC-4.1)", :aggregate_failures do
      post collection_selection_path
      stored = BulkSelection.where(account:).map(&:attributes)

      post deck_selection_path(foreign)

      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:).map(&:attributes)).to eq(stored)
      expect(BulkSelection.where(account: foreign.account)).to be_empty
    end

    it "answers 404 for a place's id, a zone's id and an id that doesn't exist, and creates nothing (AC-4.2)", :aggregate_failures do
      [ box.id, deck.zone("main").id, deck.location_id + 1000 ].each do |id|
        post deck_selection_path(id)

        expect(response).to have_http_status(:not_found)
      end
      expect(BulkSelection.where(account:)).to be_empty
    end

    it "ignores a name filter, location, sort, account or user value in the request (AC-4.3)", :aggregate_failures do
      own("Card A", location: deck.zone("main"))
      post deck_selection_path(deck), params: { q: "zzz", location: box.id, sort: "price", dir: "desc", account_id: foreign.account.id, user_id: 1, admin: "1" }

      expect(response).to redirect_to(collection_path(bulk: 1, location: deck_value))
      selection = BulkSelection.find_by!(account:)
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.account_id ]).to eq([ "", deck_value, CollectionTable::Sort.parse(nil, nil).key, account.id ])
    end

    it "sends a signed-out visitor to sign-in and creates nothing (AC-4.4)", :aggregate_failures do
      delete session_path
      post deck_selection_path(deck)

      expect(response).to redirect_to(new_session_path)
      expect(BulkSelection.where(account:)).to be_empty
    end

    it "answers no GET, prefetch-marked or not, and changes nothing (AC-4.5)", :aggregate_failures do
      get "/decks/#{deck.location_id}/selection"
      expect(response).to have_http_status(:not_found)

      get "/decks/#{deck.location_id}/selection", headers: { "Sec-Purpose" => "prefetch" }
      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:)).to be_empty
    end

    it "keeps the place shortcut's 404 for a deck's and a zone's id, and its answer for a place (AC-4.6)", :aggregate_failures do
      [ deck.location, deck.zone("main") ].each do |other|
        post location_selection_path(other)

        expect(response).to have_http_status(:not_found)
      end
      post location_selection_path(box)

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path(bulk: 1, location: box.id))
    end
  end
end
