require "rails_helper"

# Spec 041: "Move to…" in bulk mode.
RSpec.describe "Bulk Move to…", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def twin(lot, **options) = create(:lot, account:, entry: lot.entry, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def bar_count = page_html.at_css(".c-bulkbar__count").text
  def selected_names = page_html.css("tbody tr[aria-selected=true]").map { |row| row.at_css("a")&.text.to_s }

  # Edit many, then the bulk form's submission for the pressed control: it records the page's ticks first (spec 006 FR-4).
  def select_lots(*lots, go: "move", location: "", page: nil)
    post collection_selection_path, params: { location: }
    patch collection_selection_path, params: { go:, q: "", rendered_q: "", rendered_location: location, all_rendered: "0", page:,
      shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }.compact
  end

  # "Select all", with the exceptions unticked (they were ticked when the page rendered).
  def select_everything(shown, except: [], go: "move", location: "")
    post collection_selection_path, params: { location: }
    patch collection_selection_path, params: { go:, rendered_q: "", rendered_location: location, all_rendered: "0", all: "1", header_toggled: "1",
      shown_ids: shown.map(&:id), baseline_ids: shown.map(&:id), ticked_ids: (shown - except).map(&:id) }
  end

  describe "the bulk bar (Story 1)" do
    it "offers Move to… after Set condition and before Remove, in the bar and in the menu (AC-1.1)", :aggregate_failures do
      own
      post collection_selection_path
      get collection_path(bulk: 1)
      expect(page_html.css(".c-bulkbar__extra button").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      expect(page_html.css(".c-bulkbar__more .c-menu__item").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      button = page_html.at_css('.c-bulkbar__extra button[value=move]')
      expect([ button["form"], button["name"], button["type"] ]).to eq(%w[bulk go submit])
    end

    context "when the account has no location (AC-1.2)" do
      before { Location.where(account:).delete_all }

      it "offers no Move to…, and a submission asking for it is a navigation that moves nothing", :aggregate_failures do
        lot = own
        post collection_selection_path
        get collection_path(bulk: 1)
        expect(page_html.css(".c-bulkbar button").map(&:text)).to eq([ "Set condition…", "Remove", "Set condition…", "Remove", "Done" ])
        select_lots(lot)
        expect(response).to redirect_to(collection_path(bulk: 1))
        expect(response).to have_http_status(:see_other)
        expect(lot.reload.location).to be_nil
      end
    end
  end

  describe "pressing Move to…" do
    it "records the ticks and opens the move page, keeping the page (AC-1.3)", :aggregate_failures do
      lot = own
      select_lots(lot, page: 1)
      expect(response).to redirect_to(new_collection_move_path(page: 1)) # act passes the submitted page on
      expect(response).to have_http_status(:see_other)
      select_lots(lot, page: 3)
      expect(response).to redirect_to(new_collection_move_path(page: 3))
      get new_collection_move_path
      expect(page_html.at_css("h1").text).to eq("Move 1 item") # the ticks were recorded
    end

    it "refuses with the bulk table when nothing is selected (AC-1.4)", :aggregate_failures do
      own
      select_lots(go: "move")
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("Select at least one item.")
      expect(page_html.at_css(".c-bulkbar")).to be_present
    end

    it "refuses when the ticked lot was removed in another tab (AC-1.5)", :aggregate_failures do
      gone = own
      post collection_selection_path
      gone.destroy!
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ gone.id ], ticked_ids: [ gone.id ] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
    end

    it "refuses when every ticked lot is another account's, so none is left (AC-1.5, AC-5.1)", :aggregate_failures do
      theirs = create(:lot, account: create(:user).account)
      post collection_selection_path
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ theirs.id ], ticked_ids: [ theirs.id ] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
    end
  end

  describe "the move page (Story 2)" do
    it "says how many items, offers a required To select and Cancel back to the bulk table (AC-2.1, AC-2.4)", :aggregate_failures do
      lots = Array.new(4) { |i| own("Card #{i}", quantity: 3) }
      select_lots(*lots, page: 2)
      get new_collection_move_path(page: 2)
      expect(response).to have_http_status(:ok)
      expect(page_html.at_css("h1").text).to eq("Move 12 items")
      select = page_html.at_css("select#to")
      expect([ select["name"], select["required"] ]).to eq([ "to", "required" ])
      expect(page_html.css("select#to option").map { |option| [ option.text, option["value"] ] })
        .to eq([ [ "Choose…", "" ], [ "No location", "none" ], [ "Blue binder", blue.id.to_s ], [ "Long box", box.id.to_s ] ])
      expect(page_html.at_css("select#to option[selected]").text).to eq("Choose…")
      expect(page_html.at_css("label[for=to]").text).to eq("To")
      expect(page_html.at_css("input[type=submit]")["value"]).to eq("Move")
      expect(page_html.at_css(".c-form__actions a")["href"]).to eq(collection_path(bulk: 1, page: 2))
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1, page: 2))
      expect(page_html.at_css("main form.c-form")["action"]).to eq(collection_move_path(page: 2)) # the appbar has a Sign out form of its own
    end

    it "says 'Move 1 item' for one copy" do
      select_lots(own)
      get new_collection_move_path
      expect(page_html.at_css("h1").text).to eq("Move 1 item")
    end

    it "leaves out the selection's own place (AC-2.1)", :aggregate_failures do
      in_box = own(location: box)
      select_lots(in_box, location: box.id.to_s)
      get new_collection_move_path
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Blue binder" ])
      unplaced = own("Opt")
      select_lots(unplaced, location: CollectionFilter::Place::NONE)
      get new_collection_move_path
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "Blue binder", "Long box" ])
    end

    it "keeps the tab bar on Collection, as Set condition's page does" do
      select_lots(own)
      get new_collection_move_path
      expect(page_html.at_css('.c-tabbar a[aria-current="page"]').text).to include("Collection")
    end
  end

  describe "the GET answers (decision 6)" do
    it "sends the collector back to the bulk table when nothing is selected (AC-1.6)" do
      get new_collection_move_path
      expect([ response.location, flash[:alert] ]).to eq([ "http://www.example.com#{collection_path(bulk: 1)}", "Select at least one item." ])
    end

    it "does the same for a selection whose lots are gone (decision 6 (1))", :aggregate_failures do
      lot = own
      select_lots(lot)
      lot.destroy!
      get new_collection_move_path
      expect([ response.status, flash[:alert] ]).to eq([ 303, "Select at least one item." ])
    end

    it "answers 'You have no locations yet.' with a selection and no location (AC-1.7)", :aggregate_failures do
      lot = own
      select_lots(lot)
      Location.where(account:).delete_all
      get new_collection_move_path
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:alert]).to eq("You have no locations yet.")
      get collection_path(bulk: 1)
      expect(bar_count).to eq("1 of 1 selected") # the selection is kept
    end

    it "asks nothing of the selection or the lots when the request is a prefetch (AC-5.4)", :aggregate_failures do
      lot = own
      select_lots(lot)
      expect { get new_collection_move_path, headers: { "X-Sec-Purpose" => "prefetch" } }.not_to change { [ Lot.pluck(:id, :location_id, :updated_at), BulkSelection::Mark.count ] }
    end

    it "runs the same queries for 1 and 30 selected lots and for 1 and 30 locations (NFR)" do
      select_lots(own)
      get new_collection_move_path
      few = count_queries { get new_collection_move_path }
      lots = Array.new(29) { |i| own("Card #{i}") }
      29.times { create(:location, account:) }
      select_lots(*lots, own("Another"))
      expect(count_queries { get new_collection_move_path }).to eq(few)
    end
  end

  describe "moving (Story 3)" do
    it "moves the three lots with the same ids and says how many items (AC-3.1)", :aggregate_failures do
      lots = [ own("Card A", location: box, quantity: 2), own("Card B", location: box, quantity: 5), own("Card C", location: box, quantity: 1) ]
      select_lots(*lots)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:notice]).to eq("Moved 8 items to Blue binder.")
      expect(account.lots.order(:id).pluck(:id, :location_id, :quantity)).to eq(lots.map { |lot| [ lot.id, blue.id, lot.quantity ] })
    end

    it "moves to no location (AC-3.2)", :aggregate_failures do
      lots = [ own("Card A", location: blue, quantity: 2), own("Card B", location: box) ]
      select_lots(*lots)
      post collection_move_path, params: { to: "none" }
      expect(flash[:notice]).to eq("Moved 3 items to no location.")
      expect(lots.map { |lot| lot.reload.location_id }).to eq([ nil, nil ])
    end

    it "merges into the destination's lot, which survives (AC-3.3)", :aggregate_failures do
      moved = own(location: box, quantity: 2)
      survivor = twin(moved, location: blue, quantity: 3)
      select_lots(moved)
      post collection_move_path, params: { to: blue.id }
      expect([ survivor.reload.quantity, Lot.exists?(moved.id) ]).to eq([ 5, false ])
    end

    it "keeps the returning page and the filters in the redirect (AC-3.1)" do
      select_lots(own("Bolt A"), page: 1)
      post collection_move_path(page: 2), params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
    end

    it "counts the copies already there (AC-3.6)", :aggregate_failures do
      there = own("Card A", location: blue, quantity: 3)
      coming = own("Card B", location: box, quantity: 2)
      select_lots(there, coming)
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder. 3 items were already there.")
    end

    it "says '1 item was already there' (AC-3.6)", :aggregate_failures do
      select_lots(own("Card A", location: blue), own("Card B", location: box))
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 1 item to Blue binder. 1 item was already there.")
    end

    it "says it for no location too (AC-3.6)" do
      select_lots(own("Card A"), own("Card B", location: box, quantity: 2))
      post collection_move_path, params: { to: "none" }
      expect(flash[:notice]).to eq("Moved 2 items to no location. 1 item was already there.")
    end

    it "leaves a selected lot already there as the target and selected (AC-3.12)", :aggregate_failures do
      a = own(location: box, quantity: 2)
      b = twin(a, location: blue, quantity: 3)
      select_lots(a, b)
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder. 3 items were already there.")
      expect([ b.reload.quantity, Lot.exists?(a.id) ]).to eq([ 5, false ])
      follow_redirect!
      expect([ bar_count, selected_names.size ]).to eq([ "5 of 5 selected", 1 ])
    end

    it "counts only the copies that moved when a selected lot was removed in another tab (Error Scenarios)", :aggregate_failures do
      kept = own("Card A", location: box, quantity: 2)
      gone = own("Card B", location: box, quantity: 3)
      select_lots(kept, gone)
      gone.destroy!
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder.")
      expect(kept.reload.location).to eq(blue)
    end

    it "does not touch the session's bulk removal Undo (AC-3.11)", :aggregate_failures do
      removed = own("Opt")
      select_lots(removed, go: "remove")
      post collection_bulk_removals_path
      moved = own("Card A", location: box)
      select_lots(moved)
      post collection_move_path, params: { to: blue.id }
      expect(BulkRemoval.undoable.count).to eq(1)
    end
  end

  describe "the selection after a move (AC-3.9, AC-3.13)" do
    it "keeps the lots now holding the moved copies selected under all locations, a merged survivor and an excepted destination lot too (AC-3.9)", :aggregate_failures do
      a = own("Card A", location: box, quantity: 2)
      excepted = twin(a, location: blue, quantity: 3)
      c = own("Card C", quantity: 1)
      select_everything([ a, excepted, c ], except: [ excepted ])
      post collection_move_path, params: { to: blue.id }
      follow_redirect!
      expect(bar_count).to eq("All 6 items selected")
      expect(page_html.css("tbody tr").size).to eq(2)
      expect(page_html.css("tbody tr[aria-selected=true]").size).to eq(2)
    end

    it "keeps the lots selected under a name filter too (AC-3.9)", :aggregate_failures do
      bolt = own("Bolt A", location: box)
      own("Opt", location: box)
      post collection_selection_path, params: { q: "bolt" }
      patch collection_selection_path, params: { go: "move", q: "bolt", rendered_q: "bolt", rendered_location: "", all_rendered: "0", shown_ids: [ bolt.id ], ticked_ids: [ bolt.id ] }
      post collection_move_path, params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt"))
      follow_redirect!
      expect(bar_count).to eq("1 of 1 selected")
    end

    it "restarts empty under a location filter (AC-3.13)", :aggregate_failures do
      lot = own(location: box)
      select_lots(lot, location: box.id.to_s)
      post collection_move_path, params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, location: box.id))
      follow_redirect!
      expect(bar_count).to eq("0 of 0 selected")
      expect(page_html.css("tbody tr")).to be_empty
      expect(page_html.at_css(".c-empty").text).to eq("No cards in your collection are in “Long box”.") # spec 037 AC-1.6
    end

    it "restarts empty under no location, listing what is left (AC-3.13)", :aggregate_failures do
      moved = own("Card A")
      own("Card B")           # unplaced and unticked: it stays, so the table still renders under No location
      own("Card C", location: box)
      select_lots(moved, location: "none")
      post collection_move_path, params: { to: blue.id }
      follow_redirect!
      expect(bar_count).to eq("0 of 1 selected")
      expect(page_html.at_css("thead input[type=checkbox]")["checked"]).to be_nil
    end
  end

  describe "everything a filter shows (Story 4)" do
    it "moves exactly the matching lots that are not exceptions, resolved at run time (AC-4.1, AC-4.2)", :aggregate_failures do
      a, kept = own("Card A", location: box), own("Card B", location: box)
      elsewhere = own("Card D", location: blue)
      select_everything([ a, kept ], except: [ kept ], location: box.id.to_s)
      late = own("Card C", location: box) # added to Long box after the selection was made
      post collection_move_path, params: { to: "none" }
      expect([ a, late, kept, elsewhere ].map { |lot| lot.reload.location_id }).to eq([ nil, nil, box.id, blue.id ])
      expect(flash[:notice]).to eq("Moved 2 items to no location.")
      follow_redirect!
      expect([ bar_count, page_html.css("tbody tr").size ]).to eq([ "0 of 1 selected", 1 ])
    end

    it "lands on the nearest real page when the move empties the last one (AC-4.2)", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      lots = [ own("Card A", location: box), own("Card B", location: box) ]
      select_lots(lots.last, location: box.id.to_s, page: 2)
      post collection_move_path(page: 2), params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, location: box.id, page: 2))
      follow_redirect!
      expect([ response.status, page_html.css("tbody tr").size ]).to eq([ 200, 1 ])
    end

    it "moves only the unplaced lots matching the name under a name filter and No location (AC-4.3)", :aggregate_failures do
      bolt = own("Bolt A")
      placed = own("Bolt B", location: box)
      other = own("Opt")
      post collection_selection_path, params: { q: "bolt", location: "none" }
      patch collection_selection_path, params: { go: "move", q: "bolt", rendered_q: "bolt", location: "none", rendered_location: "none", all_rendered: "0", all: "1",
        header_toggled: "1", shown_ids: [ bolt.id ], baseline_ids: [], ticked_ids: [ bolt.id ] }
      post collection_move_path, params: { to: blue.id }
      expect([ bolt.reload.location, placed.reload.location, other.reload.location ]).to eq([ blue, box, nil ])
    end
  end

  describe "refusals (decision 6, in its order)" do
    let!(:lot) { own(location: box, quantity: 2) }

    before { select_lots(lot) }

    it "(1) answers a GET with no selection 'Select at least one item.' even with no location (order)", :aggregate_failures do
      BulkSelection.where(account:).destroy_all
      lot.update!(location: nil)
      Location.where(account:).delete_all
      get new_collection_move_path
      expect([ response.status, flash[:alert] ]).to eq([ 303, "Select at least one item." ])
    end

    it "(2) answers 'You have no locations yet.' before 'None of the selected items…' (order)", :aggregate_failures do
      lot.update!(location: nil)
      Location.where(account:).delete_all
      lot.destroy!
      post collection_move_path, params: { to: "" }
      expect([ response.status, flash[:alert] ]).to eq([ 303, "You have no locations yet." ])
    end

    it "(3) answers 'None of the selected items…' before the missing destination (order)", :aggregate_failures do
      lot.destroy!
      post collection_move_path, params: { to: "" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
      expect(page_html.at_css(".c-field--invalid")).to be_nil
    end

    def selection_kept
      get collection_path(bulk: 1)
      bar_count
    end

    it "(2) answers 'You have no locations yet.' with any destination, selection kept (AC-1.7)", :aggregate_failures do
      lot.update!(location: nil) # a location that holds a lot cannot be removed (restrict foreign key)
      Location.where(account:).delete_all
      post collection_move_path, params: { to: "none" }
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:alert]).to eq("You have no locations yet.")
      post collection_move_path, params: { to: "424242" }
      expect(response).to have_http_status(:see_other)
      expect(selection_kept).to eq("2 of 2 selected")
    end

    it "(3) answers 422 with 'None of the selected items…' when the selection selects no lot", :aggregate_failures do
      lot.destroy!
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
      expect(page_html.at_css("h1").text).to eq("Move 0 items")
    end

    it "(3) answers the same when the session never made a selection" do
      BulkSelection.where(account:).destroy_all # the session never made a selection (signing in again is redirected while signed in)
      post collection_move_path, params: { to: "none" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "(4) asks to choose a destination on the To field when none was chosen (AC-2.2)", :aggregate_failures do
      [ {}, { to: "" }, { to: " " } ].each do |params|
        post collection_move_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(page_html.at_css(".c-field--invalid .c-field__error").text).to eq("Choose where to move them.")
        expect(page_html.at_css("select#to")["aria-describedby"]).to eq(page_html.at_css(".c-field__error")["id"])
      end
      expect([ lot.reload.location, selection_kept ]).to eq([ box, "2 of 2 selected" ])
    end

    it "(4) keeps Back and Cancel on the bulk table with its filters, sort and page when it re-renders (AC-2.4)", :aggregate_failures do
      select_lots(lot, location: box.id.to_s)
      post collection_move_path(page: 2), params: { to: "" }
      bulk = collection_path(bulk: 1, location: box.id, page: 2)
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(bulk)
      expect(page_html.at_css(".c-form__actions a")["href"]).to eq(bulk)
    end

    it "(5) answers 404 for another account's location or one removed meanwhile, changing nothing (AC-2.3, AC-5.2)", :aggregate_failures do
      theirs = create(:location, account: create(:user).account)
      gone = create(:location, account:)
      id = gone.id
      gone.destroy!
      [ theirs.id, id, 0, "abc", "017", "9" * 19, [ "none" ], { x: 1 } ].each do |value|
        post collection_move_path, params: { to: value }
        expect(response).to have_http_status(:not_found)
      end
      expect([ lot.reload.location, theirs.lots.count, selection_kept ]).to eq([ box, 0, "2 of 2 selected" ])
    end

    it "(5) answers 404 when the destination is removed after it was looked up, changing nothing (decision 6 (5))", :aggregate_failures do
      allow(Lot::BulkMove).to receive(:new).and_wrap_original do |original, **options|
        Location.where(id: options[:to].id).delete_all # the destination goes between the lookup and the write
        original.call(**options)
      end
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:not_found)
      expect([ lot.reload.location, selection_kept ]).to eq([ box, "2 of 2 selected" ])
    end

    it "(6) refuses when every selected lot is already there (AC-3.7)", :aggregate_failures do
      post collection_move_path, params: { to: box.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("The selected items are already in Long box.")
      expect(page_html.at_css("select#to option[selected]").text).to eq("Long box")
      expect(selection_kept).to eq("2 of 2 selected")
    end

    it "(6) refuses 'already have no location' for unplaced lots (AC-3.7)" do
      unplaced = own("Opt")
      select_lots(unplaced)
      post collection_move_path, params: { to: "none" }
      expect([ response.status, page_html.at_css("#status").text ]).to match([ 422, a_string_including("The selected items already have no location.") ])
    end

    it "(6) refuses a merge past 9,999, naming the first selected lot, changing nothing (AC-3.8)", :aggregate_failures do
      held = twin(lot, location: blue, quantity: 9_999)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("Nothing moved. Lightning Bolt (#{ApplicationController.helpers.set_number(lot.entry)}) would have more than 9,999 copies in one lot.")
      expect([ lot.reload.location, held.reload.quantity, selection_kept ]).to eq([ box, 9_999, "2 of 10,001 selected" ])
    end

    it "ignores another account's lot ids and an account, user or admin value (AC-5.1, AC-5.3)", :aggregate_failures do
      other = create(:user)
      theirs = create(:lot, account: other.account)
      post collection_selection_path
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ lot.id, theirs.id ], ticked_ids: [ lot.id, theirs.id ] }
      post collection_move_path, params: { to: blue.id, account_id: other.account.id, user_id: other.id, admin: "1", location_id: box.id }
      expect([ lot.reload.location, theirs.reload.location, theirs.account_id ]).to eq([ blue, nil, other.account.id ])
      expect(user.reload.admin?).to be(false)
    end
  end

  describe "a stale page submitted twice" do
    it "finds the lots already there under all locations (AC-3.7) and creates or loses no copy", :aggregate_failures do
      lot = own(location: box, quantity: 2)
      select_lots(lot)
      post collection_move_path, params: { to: blue.id }
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("The selected items are already in Blue binder.")
      expect(account.lots.sum(:quantity)).to eq(2)
    end

    it "finds the selection restarted empty under a location filter (decision 6)", :aggregate_failures do
      lot = own(location: box, quantity: 2)
      select_lots(lot, location: box.id.to_s)
      post collection_move_path, params: { to: blue.id }
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
      expect(account.lots.sum(:quantity)).to eq(2)
    end
  end

  # Characterisation: green on arrival, the path with no scripting needs no new code (Task 13).
  it "moves the lots with plain forms: tick, press Move to…, choose, press Move (AC-6.1)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: the whole no-script flow, read from the forms
    lots = [ own("Card A", quantity: 2), own("Card B", quantity: 1) ]
    post collection_selection_path
    get collection_path(bulk: 1)
    bulk = page_html.at_css("form#bulk")
    expect(bulk["method"]).to eq("post")
    expect(page_html.at_css("button[form=bulk][name=go][value=move]")).to be_present
    ids = page_html.css("tbody input[name='shown_ids[]']").map { |input| input["value"] }
    # What a browser without scripting submits: the shown ids, the ticked ones, the pressed button.
    patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", header_toggled: "0", page: 1,
      shown_ids: ids, ticked_ids: ids }
    follow_redirect!
    form = page_html.css("main form").find { |candidate| URI(candidate["action"]).path == collection_move_path } # its action carries ?page=1
    expect(form).to be_present
    expect(form.css("[data-controller]")).to be_empty
    expect(form.at_css("select[name=to][required]")).to be_present
    post form["action"], params: { to: blue.id }
    follow_redirect!
    expect(page_html.at_css("#status").text).to include("Moved 3 items to Blue binder.")
    expect(lots.map { |lot| lot.reload.location }).to eq([ blue, blue ])
  end

  # Spec 062 D6, AC-5.1, AC-5.2, AC-5.7a, AC-5.8a: a deck and its zones are not destinations, and a lot in a zone moves out.
  describe "with a deck (spec 062)" do
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
    def zone = deck.zone("main")

    before { deck }

    # A lot in the deck's Main of a printing no other lot holds.
    def in_zone(name = "Zone card", **options)
      create_lot_in_zone(deck, "main", entry: create(:mtg_printing).entry.tap { it.update!(name:) }, **options)
    end

    it "offers No location and the places, never a deck or a zone (AC-5.1)", :aggregate_failures do
      select_lots(own("Placed", location: box))
      get new_collection_move_path
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Blue binder", "Long box" ])
    end

    it "answers 404 for a zone's id and a deck's id as the destination, changing nothing (AC-5.2)", :aggregate_failures do
      zoned = in_zone
      select_lots(zoned)
      [ zone.id, deck.location_id ].each do |id|
        post collection_move_path, params: { to: id }
        expect(response).to have_http_status(:not_found)
      end
      expect(zoned.reload.location).to eq(zone)
    end

    it "moves a zone lot, a place lot and an unplaced lot to a place, merging where an identity meets (AC-5.7a)", :aggregate_failures do
      zoned = in_zone("Card A", quantity: 2)
      placed = own("Card B", location: box, quantity: 3)
      unplaced = own("Card C", quantity: 1)
      survivor = twin(zoned, location: blue, quantity: 4)
      select_lots(zoned, placed, unplaced)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:see_other)
      expect(survivor.reload.quantity).to eq(6)
      expect([ placed, unplaced ].map { |lot| lot.reload.location }).to eq([ blue, blue ])
      expect(Lot.where(id: zoned.id)).to be_empty
      expect(account.lots.joins(:location).where(locations: { kind: "deck_zone" })).to be_empty
    end

    it "moves a zone lot to No location, and counts it as moved, never as already there (AC-5.7a)", :aggregate_failures do
      zoned = in_zone(quantity: 2)
      select_lots(zoned)
      post collection_move_path, params: { to: "none" }
      expect(flash[:notice]).to eq("Moved 2 items to no location.")
      expect(zoned.reload.location).to be_nil
    end

    it "honours the 9,999 cap for a zone lot moving into a place (AC-5.7a)", :aggregate_failures do
      zoned = in_zone(quantity: 2)
      held = twin(zoned, location: blue, quantity: 9_999)
      select_lots(zoned)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect([ zoned.reload.location, held.reload.quantity ]).to eq([ zone, 9_999 ])
    end

    context "when the account has a deck and no place (AC-5.8a)" do
      before { Location.places.where(account:).delete_all }

      it "answers 'You have no locations yet.' to the page and offers no Move to… to a submission", :aggregate_failures do
        zoned = in_zone
        select_lots(zoned)
        expect(response).to redirect_to(collection_path(bulk: 1)) # a navigation, not the move page
        get new_collection_move_path
        expect(response).to redirect_to(collection_path(bulk: 1))
        expect(flash[:alert]).to eq("You have no locations yet.")
        expect(zoned.reload.location).to eq(zone)
      end
    end
  end
end
