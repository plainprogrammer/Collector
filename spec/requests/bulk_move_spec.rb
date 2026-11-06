require "rails_helper"

# Spec 041: "Move to…" in bulk mode.
RSpec.describe "Bulk Move to…", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  before do
    sign_in_as(user)
    create(:location, account:, name: "Blue binder")
    create(:location, account:, name: "Long box")
  end

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
end
