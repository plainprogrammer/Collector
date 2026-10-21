require "rails_helper"

# Spec 029 Stories 1 to 5: the locations pages, tenancy and the ways to them.
RSpec.describe "Locations", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def html = Nokogiri::HTML5(response.body)
  def listed = html.css(".c-locations__list .c-locations__name").map(&:text)
  def field_error = html.at_css("#location_name-error")&.text
  def add(name, **extra) = post(locations_path, params: { location: { name: } }.merge(extra))
  def notice = html.at_css("#status")&.text.to_s.squish

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the heading, the add form and the empty state (AC-1.1)", :aggregate_failures do
      get locations_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Locations")
      expect(html.at_css("form[action='#{locations_path}'] input[type=submit]")["value"]).to eq("Add location")
      expect(html.at_css("form[action='#{locations_path}'] input[name='location[name]']")).to be_present
      expect(html.at_css(".c-empty").text).to eq("No locations yet. Add a binder or a box to start recording where things are kept.")
      expect(html.at_css("main").text).not_to match(/magic|mtg|scryfall/i) # the footer's content notice is outside main
    end

    it "adds a location, redirects (303) and says so, in the order of AC-1.4 (AC-1.2, AC-1.4, AC-1.12)", :aggregate_failures do
      add("Blue binder")

      expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
      follow_redirect!
      expect(notice).to eq("Added “Blue binder”.")
      expect(listed).to eq([ "Blue binder" ])
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      expect(html.css("form[data-controller], form[data-turbo]")).to be_empty # a plain form: no script needed

      [ "box", "Binder 2", "Binder 10", "Éclair", "eclair" ].each { |name| add(name) }
      get locations_path
      expect(listed).to eq([ "Binder 10", "Binder 2", "Blue binder", "box", "eclair", "Éclair" ])
    end

    it "answers 422 with the reason beside the field and the typed text kept (AC-1.6 to AC-1.9)", :aggregate_failures do
      add("Blue binder")
      {
        "   " => "Give the location a name.",
        ("a" * 61) => "Names can be at most 60 characters.",
        "a\u200Bb" => "Names can't contain control characters.",
        "  blue   BINDER " => "You already have a location called “blue BINDER”."
      }.each do |typed, message|
        add(typed)
        expect(response).to have_http_status(:unprocessable_content)
        expect(field_error).to eq(message)
        expect(html.at_css("input[name='location[name]']")["value"]).to eq(typed)
        expect(html.at_css("input[name='location[name]']")["aria-describedby"]).to eq("location_name-error")
      end
      expect(account.locations.count).to eq(1)
    end

    it "refuses the 501st location (AC-1.10)", :aggregate_failures do
      Location.insert_all!(Array.new(500) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })

      add("One more")

      expect(response).to have_http_status(:unprocessable_content)
      expect(field_error).to eq("You can have at most 500 locations.")
      expect(account.locations.count).to eq(500)
    end

    it "answers 400 without the location parameter (AC-1.14)", :aggregate_failures do
      expect { post locations_path, params: { other: "x" } }.not_to change(Location, :count)
      expect(response).to have_http_status(:bad_request)
    end

    it "stores a name in non-Latin script as typed and a combining accent in NFC (AC-1.11)", :aggregate_failures do
      add("日本語のバインダー")
      add("Cafe\u0301")

      expect(account.locations.pluck(:name)).to contain_exactly("日本語のバインダー", "Café")
    end

    describe "renaming" do
      let!(:location) { create(:location, account:, name: "Blue binder") }

      it "opens the edit page holding the name (AC-2.1, AC-2.7)", :aggregate_failures do
        get edit_location_path(location)

        expect(html.at_css("input[name='location[name]']")["value"]).to eq("Blue binder")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.css("a").find { |link| link.text == "Cancel" }["href"]).to eq(locations_path)
      end

      it "saves, redirects and says what happened, leaving every lot alone (AC-2.2, AC-2.8)", :aggregate_failures do
        lot = create(:lot, account:, quantity: 3)
        before = lot.reload.attributes

        patch location_path(location), params: { location: { name: "Trade binder" } }

        expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
        follow_redirect!
        expect(notice).to eq("Renamed “Blue binder” to “Trade binder”.")
        expect(listed).to eq([ "Trade binder" ])
        expect(lot.reload.attributes).to eq(before)
      end

      it "allows a change of case alone, and the name it already has (AC-2.3, AC-2.6)", :aggregate_failures do
        patch location_path(location), params: { location: { name: "blue BINDER" } }
        expect(response).to have_http_status(:see_other)
        patch location_path(location), params: { location: { name: "blue BINDER" } }
        expect(response).to have_http_status(:see_other)
        expect(location.reload.name).to eq("blue BINDER")
      end

      it "refuses another location's key, and the reasons of a new name, keeping the name (AC-2.4, AC-2.5)", :aggregate_failures do
        create(:location, account:, name: "Trade binder")

        { "TRADE binder" => "You already have a location called “TRADE binder”.", "" => "Give the location a name.",
          ("a" * 61) => "Names can be at most 60 characters.", "a\u0007b" => "Names can't contain control characters." }.each do |typed, message|
          patch location_path(location), params: { location: { name: typed } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(field_error).to eq(message)
        end
        expect(location.reload.name).to eq("Blue binder")
      end

      it "lets the later of two saves stand (AC-2.9)", :aggregate_failures do
        patch location_path(location), params: { location: { name: "First" } }
        patch location_path(location), params: { location: { name: "Second" } }

        expect(location.reload.name).to eq("Second")
      end

      it "answers 404 once the location is gone, creating nothing (AC-2.10, AC-3.7)", :aggregate_failures do
        location.destroy!

        patch location_path(location), params: { location: { name: "Back again" } }
        expect(response).to have_http_status(:not_found)
        get edit_location_path(location)
        expect(response).to have_http_status(:not_found)
        expect(account.locations.count).to eq(0)
      end
    end

    describe "removing" do
      let!(:location) { create(:location, account:, name: "Blue binder") }

      it "asks first, naming the location, and removes nothing on a GET (AC-3.1)", :aggregate_failures do
        get new_location_removal_path(location)

        expect(html.at_css("h1").text).to eq("Remove Blue binder?")
        expect(html.at_css("form[action='#{location_path(location)}'] button")&.text).to eq("Remove")
        expect(html.css("a").find { |link| link.text == "Cancel" }["href"]).to eq(locations_path)
        expect(account.locations.count).to eq(1)
      end

      it "removes on DELETE, redirects and says so, and the name can be added again (AC-3.2, AC-3.5)", :aggregate_failures do
        delete location_path(location)

        expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
        follow_redirect!
        expect(notice).to eq("Removed “Blue binder”.")
        expect(account.locations.count).to eq(0)
        add("Blue binder")
        expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      end

      it "never touches a lot (AC-3.4)", :aggregate_failures do
        lots = create_list(:lot, 2, account:, quantity: 4)
        before = lots.map { |lot| lot.reload.attributes }

        delete location_path(location)

        expect(account.lots.order(:id).map(&:attributes)).to eq(before)
      end

      it "answers 404 for one that is already gone, with no message (AC-3.6)", :aggregate_failures do
        delete location_path(location)
        delete location_path(location)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "only this account (Story 4)" do
      let(:other) { create(:user).account }
      let!(:theirs) { create(:location, account: other, name: "Zebulon's crate") }

      it "answers 404 for another account's location on every page and write, leaving it unchanged (AC-4.1)", :aggregate_failures do
        get edit_location_path(theirs)
        expect(response).to have_http_status(:not_found)
        get new_location_removal_path(theirs)
        expect(response).to have_http_status(:not_found)
        patch location_path(theirs), params: { location: { name: "Mine now" } }
        expect(response).to have_http_status(:not_found)
        delete location_path(theirs)
        expect(response).to have_http_status(:not_found)
        expect(theirs.reload.name).to eq("Zebulon's crate")
      end

      it "lists only mine, and lets me use a name another account has (AC-4.2)", :aggregate_failures do
        create(:location, account:, name: "Mine")
        add("Zebulon's crate")
        get locations_path

        expect(listed).to eq([ "Mine", "Zebulon's crate" ])
        expect(account.locations.count).to eq(2)
        expect(other.locations.count).to eq(1)
      end

      it "makes the location mine whatever account_id the request carries (AC-4.3)", :aggregate_failures do
        add("Sneaky", account_id: other.id, location: { name: "Sneaky", account_id: other.id })

        expect(account.locations.pluck(:name)).to eq([ "Sneaky" ])
        expect(other.locations.pluck(:name)).to eq([ "Zebulon's crate" ])
      end
    end

    describe "the ways in (Story 5)" do
      it "adds Locations after Scan in the header, current on its pages, and no tab is marked (AC-5.1, AC-5.3)", :aggregate_failures do
        get collection_path
        expect(html.css(".c-appbar__nav a").map(&:text)).to eq(%w[Collection Search Scan Locations])
        expect(html.css(".c-tabbar a").map { |link| link.text.strip }).to eq(%w[Collection Search Scan More])

        create(:location, account:)
        [ locations_path, edit_location_path(account.locations.first), new_location_removal_path(account.locations.first) ].each do |path|
          get path
          expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Locations" ]), path
          expect(html.css(".c-appbar__nav a").find { |link| link.text == "Locations" }["href"]).to eq(locations_path)
          expect(html.css(".c-tabbar [aria-current]")).to be_empty, path
        end
      end

      it "puts a Locations row in More before Export collection, and not in the account menu (AC-5.2)", :aggregate_failures do
        get more_path

        rows = html.css(".c-more li").map { |row| row.text.squish }
        expect(rows.first).to start_with("Signed in as")
        expect(html.css(".c-more li a").map(&:text).first(4)).to eq([ "Locations", "Export collection", "Import collection", "Add by number" ])
        expect(html.at_css(".c-more a[href='#{locations_path}']")).to be_present
        expect(html.css(".c-appbar .c-menu__list a").map(&:text)).not_to include("Locations")
      end
    end

    it "shows no location, name or count on the admin pages (AC-4.5)", :aggregate_failures do
      create(:location, account:, name: "Zebulon's crate")
      admin = create(:admin)
      create(:location, account: admin.account, name: "Admin's shelf")
      delete session_path # the before block signed in the member; a second sign-in would not replace that session
      sign_in_as(admin)

      [ admin_users_path, admin_catalog_path, admin_jobs_path ].each do |path|
        get path
        main = html.at_css("main").text
        expect(response.body).not_to include("Zebulon", "Admin&#39;s shelf", "Admin's shelf"), path
        expect(main.downcase).not_to include("location"), path # the header's own link is outside main
      end
    end
  end

  describe "when signed out (AC-4.4, AC-5.4)" do
    let!(:location) { create(:location, name: "Hidden") }

    def expect_visitor_sent_to_sign_in
      [ locations_path, edit_location_path(location), new_location_removal_path(location) ].each do |path|
        get path
        expect(response).to redirect_to(new_session_path), path
      end
      expect(response.body).not_to include("Hidden")
    end

    it "sends a visitor to sign in from every page and shows nothing", :aggregate_failures do
      expect_visitor_sent_to_sign_in
    end

    # The OpenCatalog concern opens the catalog's pages only (CLAUDE.md, Open catalog); the locations pages stay closed.
    it "does the same with the catalog open (AC-4.4, FR-1 Must not)", :aggregate_failures, :public_catalog do
      expect_visitor_sent_to_sign_in
    end

    it "sends a write with an ended session to sign in and writes nothing", :aggregate_failures do
      user = create(:user)
      owned = create(:location, account: user.account, name: "Mine")
      sign_in_as(user)
      delete session_path

      post locations_path, params: { location: { name: "New" } }
      patch location_path(owned), params: { location: { name: "Changed" } }
      delete location_path(owned)

      expect(response).to redirect_to(new_session_path)
      expect(user.account.locations.pluck(:name)).to eq([ "Mine" ])
    end

    it "fails forgery protection first for a write with no session cookie", :aggregate_failures do
      ActionController::Base.allow_forgery_protection = true

      post locations_path, params: { location: { name: "New" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Location.where(name: "New")).to be_empty
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "shows a visitor of an open catalog no Locations link (AC-5.4)", :aggregate_failures, :public_catalog do
      get catalog_entries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Locations")
    end
  end
end
