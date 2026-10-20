require "rails_helper"

# Spec 023: with the operator's setting on, catalog search, card pages and all printings answer visitors, with no
# collection part and no tenant data; with it off, nothing changes.
RSpec.describe "The catalog for visitors", type: :request do
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt", external_key: "oracle-bolt") }
  let(:printing) do
    create(:catalog_entry, identity: bolt, set: create(:catalog_set, code: "lea", name: "Limited Edition Alpha"),
      external_key: "bolt-a", number: "161",
      image_url: "https://cards.scryfall.io/normal/front/b/o/bolt-a.jpg").tap do |entry|
      create(:mtg_printing, entry:, legalities: { "modern" => "legal", "standard" => "not_legal" },
        faces: [ { "name" => "Lightning Bolt", "mana_cost" => "{R}", "type_line" => "Instant",
                   "oracle_text" => "Lightning Bolt deals 3 damage to any target.", "artist" => "Christopher Rush",
                   "image_uris" => { "large" => image_url } } ])
    end
  end
  let(:other_printing) do
    create(:catalog_entry, identity: bolt, set: create(:catalog_set, code: "m10", name: "Magic 2010"),
      external_key: "bolt-b", number: "146", image_url: nil).tap { create(:mtg_printing, entry: it) }
  end
  let(:owner) { create(:user, name: "Morgan Owner", email_address: "morgan@example.com") }
  let(:collector) { create(:user) }

  before do
    create(:lot, account: owner.account, entry: printing, quantity: 2, condition: "near_mint")
    create(:lot, account: owner.account, entry: printing, quantity: 1, condition: "lightly_played")
    other_printing
  end

  def image_url = "https://cards.scryfall.io/large/front/b/o/bolt-a.jpg"

  # The three catalog pages: search, the card page and all printings.
  def pages = [ catalog_entries_path(q: "Bolt"), catalog_entry_path(printing), catalog_identity_path(bolt) ]

  def html = Nokogiri::HTML5(response.body)

  def statements_during
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] unless payload[:cached] }
    ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { yield }
    statements
  end

  def sign_out = delete(session_path)

  context "when the setting is off" do
    it "sends a visitor to sign in, and back to the page they asked for afterwards (AC-2.1)", :aggregate_failures do
      pages.each do |path|
        get path
        expect(response).to redirect_to(new_session_path), path

        sign_in_as(collector)
        expect(response).to redirect_to(path)
        sign_out
      end
    end

    it "sends a visitor whose session no longer exists to sign in (AC-2.4)", :aggregate_failures do
      sign_in_as(collector)
      Session.delete_all

      pages.each do |path|
        get path
        expect(response).to redirect_to(new_session_path), path
      end
    end
  end

  context "when no one has signed up yet" do
    before do
      Lot.delete_all
      User.delete_all
    end

    it "sends anyone to sign-up with the setting off (AC-2.3)", :aggregate_failures do
      pages.each do |path|
        get path
        expect(response).to redirect_to(new_registration_path), path
      end
    end

    it "sends anyone to sign-up with the setting on (AC-2.3)", :aggregate_failures, :public_catalog do
      pages.each do |path|
        get path
        expect(response).to redirect_to(new_registration_path), path
      end
    end
  end

  # The sign-in and sign-up pages, which have never had a tab bar (decision 3).
  def auth_pages = [ new_session_path, new_registration_path ]

  def body_classes = html.at_css("body")["class"].split

  describe "the sign-in and sign-up pages" do
    # Each page's status, whether its shell is untabbed and whether it turns Turbo's prefetch off.
    def auth_page_shells
      auth_pages.map do |path|
        get path
        [ path, response.status, body_classes.include?("c-shell--untabbed"), html.at_css("meta[name='turbo-prefetch']").present? ]
      end
    end

    it "mark the shell untabbed and keep Turbo's prefetch with the setting off (AC-5.7, AC-2.2)" do
      expect(auth_page_shells).to eq(auth_pages.map { [ it, 200, true, false ] })
    end

    it "mark the shell untabbed and keep Turbo's prefetch with the setting on (AC-5.7, decision 4)", :public_catalog do
      expect(auth_page_shells).to eq(auth_pages.map { [ it, 200, true, false ] })
    end
  end

  # Amendment 2 of the plan: for a collector, the setting changes not one byte of a catalog page.
  it "renders a collector's catalog pages identically with the setting off and on (AC-2.2)", :aggregate_failures do
    sign_in_as(owner)
    mask = ->(body) { body.gsub(/(name="csrf-token" content=")[^"]*/, '\1').gsub(/(name="authenticity_token" value=")[^"]*/, '\1') }
    bodies = ->(setting) do
      Rails.configuration.x.public_catalog = setting
      pages.map { |path| get(path).then { mask.(response.body) } }
    ensure
      Rails.configuration.x.public_catalog = false
    end

    off = bodies.(false)
    on = bodies.(true)

    pages.each_with_index { |path, index| expect(on[index]).to eq(off[index]), path }
  end

  context "when the setting is on", :public_catalog do
    def search_parts
      {
        meta: html.css(".c-results__meta > span").map(&:text),
        sets: html.css("select[name=set] option").map { [ it.text, it["value"] ] },
        groups: html.css(".c-group .c-section__title").map(&:text),
        tiles: html.css(".c-tile__name").map(&:text),
        pager: html.at_css(".c-pager")&.text&.squish
      }
    end

    it "shows a visitor the same search results, set filter, freshness line and pager as a collector (AC-3.1)",
      :aggregate_failures do
      create(:catalog_refresh_run, finished_at: Time.zone.local(2026, 10, 1, 12))
      12.times { |i| create(:catalog_entry, identity: create(:catalog_identity, name: "Lightning Echo #{i.to_s.rjust(2, "0")}")) }
      queries = [ { q: "Lightning" }, { q: "Lightning", page: 2 }, { q: "Bolt", set: "lea" }, {} ]

      as_visitor = queries.map { |query| get(catalog_entries_path(query)).then { [ response.status, search_parts ] } }
      sign_in_as(collector)
      as_collector = queries.map { |query| get(catalog_entries_path(query)).then { [ response.status, search_parts ] } }

      expect(as_visitor).to eq(as_collector)
      expect(as_visitor.map(&:first)).to all(eq(200))
      expect(as_visitor[1].last[:pager]).to eq("Previous Page 2 of 2")
      expect(as_visitor[0].last[:meta]).to eq([ "13 cards", "Catalog updated 1 October 2026" ])
    end

    it "shows a visitor the card page (AC-3.2)", :aggregate_failures do
      get catalog_entry_path(printing)

      expect(response).to have_http_status(:ok)
      expect(html.at_css(".c-item__media img")["src"]).to eq(image_url)
      expect(html.at_css("h1").text).to eq("Lightning Bolt")
      expect(html.at_css(".c-details").text).to include("Limited Edition Alpha", "LEA · 161", "Christopher Rush")
      expect(response.body).to include("Lightning Bolt deals 3 damage to any target.")
      expect(html.css(".c-legality li").map { it.text.squish }).to include("Modern Legal")
      expect(html.css("#printings .c-list li").size).to eq(2)
      expect(html.at_css("a.c-menu__item[href='https://scryfall.com/card/lea/161']").text).to eq("View on Scryfall")
    end

    it "shows a visitor all printings, with and without a set, with its pager (AC-3.3)", :aggregate_failures do
      12.times { create(:catalog_entry, identity: bolt, set: printing.set) }

      get catalog_identity_path(bolt)
      expect(response).to have_http_status(:ok)
      expect(html.css(".c-grid .c-tile").size).to eq(12)
      expect(html.at_css(".c-pager").text.squish).to eq("Page 1 of 2 Next")

      get catalog_identity_path(bolt, set: "lea", page: 2)
      expect(response).to have_http_status(:ok)
      expect(html.css(".c-grid .c-tile").size).to eq(1)
      expect(html.at_css(".c-pager").text.squish).to eq("Previous Page 2 of 2")
    end

    it "answers 404 for a missing card and for an identity with no searchable printing (AC-3.4)", :aggregate_failures do
      get "/catalog/entries/nope"
      expect(response).to have_http_status(:not_found)

      retired = create(:catalog_identity, name: "Retired Card")
      create(:catalog_entry, :retired, identity: retired)
      get catalog_identity_path(retired)
      expect(response).to have_http_status(:not_found)
    end

    it "shows a visitor no collection part and no tenant data (AC-4.1)", :aggregate_failures do
      absent = [ ".c-avatar", ".c-tile__qty", ".c-tile__add", "form[action*='quick_add']", "a[href*='/lots/new']",
                 "#copies", ".c-stat", ".c-tile--owned-none", "li.is-unowned" ]

      pages.each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        absent.each { |selector| expect(html.css(selector)).to be_empty, "#{path}: #{selector}" }
        [ "Not owned", "Your copies", "Add a copy", " owned" ].each { expect(html.text).not_to include(it), "#{path}: #{it}" }
        [ "Morgan Owner", "morgan@example.com" ].each { expect(response.body).not_to include(it), "#{path}: #{it}" }
      end
    end

    it "runs no query against lots for a visitor (AC-4.2)", :aggregate_failures do
      pages.each do |path|
        statements = statements_during { get path }
        expect(response).to have_http_status(:ok), path
        expect(statements.grep(/"lots"/)).to be_empty, path
      end
    end

    it "still sends a visitor to sign in for quick add, a new lot, the collection, the scanner and More (AC-4.3)",
      :aggregate_failures do
      expect { post catalog_entry_quick_add_path(printing) }.not_to change(Lot, :count)
      expect(response).to redirect_to(new_session_path)

      [ new_catalog_entry_lot_path(printing), collection_path, scanner_path, more_path ].each do |path|
        get path
        expect(response).to redirect_to(new_session_path), path
      end
    end

    it "gives a visitor the search context even from a collection link (AC-4.4)", :aggregate_failures do
      get catalog_entry_path(printing, from: "collection")

      expect(response).to have_http_status(:ok)
      expect(html.at_css(".c-crumbs a")["href"]).to eq(catalog_entries_path)
      expect(html.at_css(".c-appbar__back")["href"]).to eq(catalog_entries_path)
      expect(html.css("#printings a").map { it["href"] }).to all(satisfy { !it.include?("from=") })
      expect(html.css("#printings a[href^='/catalog/entries/']")).not_to be_empty
    end

    it "keeps every catalog response private for a visitor and a collector (AC-4.5)", :aggregate_failures do
      check = ->(who) do
        pages.each do |path|
          get path
          expect(response).to have_http_status(:ok), "#{who} #{path}"
          expect(response.headers["Cache-Control"]).to include("private"), "#{who} #{path}"
          expect(response.headers["Cache-Control"]).not_to include("public"), "#{who} #{path}"
        end
      end

      check.("visitor")
      sign_in_as(collector)
      check.("collector")
    end

    it "returns a visitor to the catalog page they were on when they sign in (AC-3.5)" do
      get catalog_entry_path(printing)

      sign_in_as(collector)

      expect(response).to redirect_to(catalog_entry_path(printing))
    end

    it "returns a visitor to the card page with its query string when they sign in (AC-3.5, plan amendment 7)" do
      get catalog_entry_path(printing, from: "collection")

      sign_in_as(collector)

      expect(response).to redirect_to(catalog_entry_path(printing, from: "collection"))
    end

    it "doesn't let a prefetch change where a visitor returns to (AC-3.5, decision 4)", :aggregate_failures do
      get catalog_entry_path(printing)
      get catalog_entry_path(other_printing), headers: { "X-Sec-Purpose" => "prefetch" }
      expect(response).to have_http_status(:ok)
      get catalog_entry_path(other_printing), headers: { "Sec-Purpose" => "prefetch" }

      sign_in_as(collector)

      expect(response).to redirect_to(catalog_entry_path(printing))
    end

    it "writes no return path for a collector's catalog request (AC-3.5)", :aggregate_failures do
      sign_in_as(collector)
      pages.each { get it }
      sign_out

      sign_in_as(collector)

      expect(response).to redirect_to(collection_path)
    end

    it "lands a visitor who signs up in their collection, then and after signing in again (AC-3.7)", :aggregate_failures do
      InstanceSetting.current.update!(sign_up_open: true)
      get catalog_entry_path(printing)

      post registration_path, params: { user: { name: "Ann", email_address: "ann@example.test",
        password: AuthenticationHelpers::PASSWORD, password_confirmation: AuthenticationHelpers::PASSWORD } }
      expect(response).to redirect_to(collection_path)

      sign_out
      sign_in_as(User.find_by!(email_address: "ann@example.test"))
      expect(response).to redirect_to(collection_path)
    end

    it "gives a visitor whose session no longer exists the visitor's page (AC-2.4)", :aggregate_failures do
      sign_in_as(collector)
      Session.delete_all

      pages.each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(html.at_css(".c-avatar")).to be_nil, path
      end
    end

    it "shows a collector every collection part (AC-6.1)", :aggregate_failures do
      sign_in_as(owner)

      [ catalog_entries_path(q: "Bolt"), catalog_identity_path(bolt) ].each do |path|
        get path
        expect(html.css(".c-tile__qty").map(&:text)).to eq([ "×3" ]), path
        expect(html.css(".c-tile--owned-none").size).to eq(1), path
        expect(html.css("form[action*='quick_add']").size).to eq(2), path
        expect(html.at_css(".c-avatar")).to be_present, path
        expect(html.at_css("#tabbar")).to be_present, path
      end

      get catalog_entry_path(printing)
      expect(html.at_css(".c-stat dd").text).to eq("3")
      expect(html.css("#copies tbody tr").size).to eq(2)
      expect(html.css("#printings form[action*='quick_add']").size).to eq(1)
      expect(html.at_css("a[href='#{new_catalog_entry_lot_path(printing)}']")).to be_present
      expect(html.at_css(".c-avatar")).to be_present
    end

    describe "the shell" do
      it "has no tab bar, and the footer's content notice, for a visitor (AC-5.2, AC-5.3)", :aggregate_failures do
        pages.each do |path|
          get path
          expect(html.at_css("#tabbar")).to be_nil, path
          expect(html.at_css("body > footer.c-footer").text).to include("Card data and images provided by Scryfall."), path
        end
      end

      it "tells a visitor only that the catalog hasn't been loaded (AC-5.4)", :aggregate_failures do
        create(:catalog_refresh_run, status: "failed")

        get catalog_entries_path

        expect(html.at_css("#catalog_not_loaded").text.squish).to eq("The card catalog hasn't been loaded yet.")
        expect(html.at_css("#catalog_not_loaded a")).to be_nil
      end

      it "marks the shell untabbed for a visitor and not for a collector (AC-5.7)", :aggregate_failures do
        pages.each do |path|
          get path
          expect(body_classes).to include("c-shell", "c-shell--footed", "c-shell--untabbed"), path
        end

        sign_in_as(collector)
        pages.each do |path|
          get path
          expect(html.at_css("body")["class"]).to eq("c-shell c-shell--footed"), path
        end
      end

      it "gives a visitor the brand, Search and Sign in, and nothing that needs an account (AC-5.1)",
        :aggregate_failures do
        pages.each do |path|
          get path
          header = html.at_css("body > header.c-appbar#appbar")
          brand = header.at_css("a.c-appbar__brand")
          expect([ brand["href"], brand["aria-label"] ]).to eq([ catalog_entries_path, "Collector search" ]), path
          nav = header.css("nav.c-appbar__nav > *").map { [ it.name, it.text, it["href"], it["aria-current"] ] }
          expect(nav).to eq([ [ "a", "Search", catalog_entries_path, "page" ] ]), path
          actions = header.css(".c-appbar__actions > *").map { [ it.name, it.text, it["href"], it["class"] ] }
          expect(actions).to eq([ [ "a", "Sign in", new_session_path, "c-btn c-btn--secondary c-btn--sm" ] ]), path
          expect(html.css(".c-appbar__add")).to be_empty, path
          expect(html.text).not_to include("Sign out"), path
          [ admin_users_path, admin_catalog_path, admin_jobs_path ].each do |admin|
            expect(html.css("a[href='#{admin}']")).to be_empty, "#{path}: #{admin}"
          end
        end
      end

      it "keeps the detail header, with its back link to search, on a visitor's card page (decision 3)",
        :aggregate_failures do
        get catalog_entry_path(printing)

        header = html.at_css("header#appbar")
        expect(header["class"].split).to eq(%w[c-appbar c-appbar--detail])
        expect(header.at_css("a.c-appbar__back")["href"]).to eq(catalog_entries_path)
        expect(header.at_css("a.c-appbar__brand")["href"]).to eq(catalog_entries_path)

        get catalog_entries_path(q: "Bolt")
        expect(html.at_css("header#appbar")["class"]).to eq("c-appbar")
        expect(html.at_css("a.c-appbar__back")).to be_nil
      end

      it "turns Turbo's prefetch off for a visitor only (decision 4)", :aggregate_failures do
        prefetch_off = "meta[name='turbo-prefetch'][content='false']"
        pages.each do |path|
          get path
          expect(html.at_css(prefetch_off)).to be_present, path
        end

        sign_in_as(collector)
        pages.each do |path|
          get path
          expect(html.at_css("meta[name='turbo-prefetch']")).to be_nil, path
        end
      end
    end
  end
end
