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
end
