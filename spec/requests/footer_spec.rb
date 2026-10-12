require "rails_helper"

# Spec 018: every page carries one footer with the content notices of the registered catalog types.
RSpec.describe "The footer", type: :request do
  let(:notice) do
    "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. " \
      "Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."
  end
  let(:attribution) { "Card data and images provided by Scryfall." }
  let(:links) { [ [ "Fan Content Policy", "https://company.wizards.com/en/legal/fancontentpolicy" ], [ "Scryfall", "https://scryfall.com" ] ] }

  def html = Nokogiri::HTML5(response.body)

  def footers = html.css("footer")

  def footer = html.at_css("body > footer.c-footer")

  def lines = footer.css("> p").map(&:text)

  # The one footer, straight after the page's main content where it has one, with both lines and their two links.
  def expect_the_footer(on)
    expect(footers.size).to eq(1), "#{on}: #{footers.size} footers"
    expect(lines).to eq([ notice, attribution ]), on
    expect(footer.css("a").map { |link| [ link.text, link["href"] ] }).to eq(links), on
    expect(html.css("body > main + footer.c-footer").size).to eq(1), "#{on}: not straight after main" if html.at_css("main")
  end

  describe "for a signed-in collector" do
    let(:user) { create(:user) }
    let(:lot) { create(:lot, account: user.account) }

    before { sign_in_as(user) }

    it "is on every page, after the main content (AC-1.1, AC-1.2, AC-1.6, AC-1.9, AC-1.10)", :aggregate_failures do
      [ collection_path, collection_path(view: "table"), collection_path(view: "table", bulk: 1), catalog_entries_path,
        catalog_entries_path(q: lot.entry.name), catalog_entry_path(lot.entry), catalog_identity_path(lot.entry.identity),
        scanner_path, more_path, new_catalog_entry_lot_path(lot.entry), edit_lot_path(lot),
        new_lot_removal_path(lot) ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end

    it "sits between the main content and the tab bar, and marks the shell as having it", :aggregate_failures do
      get collection_path

      expect(html.css("body > *").map(&:name).last(3)).to eq(%w[main footer nav])
      expect(html.at_css("body")["class"]).to eq("c-shell c-shell--footed")
    end

    it "is there while the catalog isn't loaded (AC-1.5)", :aggregate_failures do
      create(:catalog_refresh_run, status: "failed")

      [ collection_path, catalog_entries_path ].each do |path|
        get path
        expect_the_footer(path)
      end
    end

    it "holds the card page's only attribution (AC-1.7)", :aggregate_failures do
      get catalog_entry_path(lot.entry)

      expect(response.body.scan("Card data and images provided by").size).to eq(1)
      expect(html.at_css("main").text).not_to include("provided by")
    end

    it "is on a form shown again after a failed submission (AC-1.6)", :aggregate_failures do
      patch lot_path(lot), params: { lot: { quantity: 0 } }

      expect(response).to have_http_status(:unprocessable_content)
      expect_the_footer("lot form, 422")
    end

    it "is left out of an answer that isn't a page (AC-1.8)", :aggregate_failures do
      printings = scanner_printings_path(card: lot.entry.identity.external_key, key: "c" * 32)
      get printings, headers: { "Turbo-Frame" => "scanner_printings" }
      expect(response.body).to include("<turbo-frame")
      expect(footers).to be_empty

      post scanner_readings_path, params: { reading: { name_text: "Bolt", collector_text: "", key: "c" * 32 } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).not_to include("<footer")

      get rails_health_check_path
      expect(response.body).not_to include("<footer")

      get printings
      expect_the_footer("the same address without the Turbo-Frame header")
    end

    it "is text and its links, with nothing else in it (AC-3.5, AC-3.8)", :aggregate_failures do
      get collection_path

      expect(footer.css("*").map(&:name).uniq).to match_array(%w[p a])
      expect(footer.css("a").map { |link| link.attributes.keys }).to all(match_array(%w[rel href]))
      expect(footer.css("a").map { |link| link["rel"] }).to all(eq("noopener"))
      expect(footer.to_html).not_to match(/style=|nonce=|<script|\son\w+=/)
    end

    it "runs no query (FR-2)" do
      expect(count_queries { Catalog::ContentNotice.lines.flat_map(&:parts) }).to eq(0)
    end
  end

  describe "for a signed-out visitor" do
    it "is on the first-run sign-up page (AC-1.3)" do
      get new_registration_path

      expect_the_footer("first-run sign-up")
    end

    it "is on the sign-in page and on open sign-up (AC-1.3)", :aggregate_failures do
      create(:user)
      InstanceSetting.current.update!(sign_up_open: true)

      [ new_session_path, new_registration_path ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end

    it "is on the sign-in form shown again with 422 and with 429 (AC-1.6)", :aggregate_failures do
      user = create(:user)

      10.times { post session_path, params: { email_address: user.email_address, password: "wrong" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect_the_footer("sign-in, 422")

      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to have_http_status(:too_many_requests)
      expect_the_footer("sign-in, 429")
    end
  end

  describe "for an admin" do
    it "is on the admin pages (AC-1.4)", :aggregate_failures do
      admin = sign_in_as(create(:admin))

      [ admin_users_path, new_admin_user_path, edit_admin_user_path(admin), admin_catalog_path, admin_jobs_path ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end
  end

  describe "with other catalog types" do
    before { sign_in_as(create(:user)) }

    it "shows a second type's lines after the first's, a link only where a line names one (AC-2.1, AC-2.7)", :aggregate_failures do
      register_notice_catalog("zeta", notice_line("Zeta is shown with its owner's leave."),
        notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test/about"))
      get collection_path

      expect(lines).to eq([ notice, attribution, "Zeta is shown with its owner's leave.", "Data from Zeta Base." ])
      expect(footer.css("> p")[2].css("a")).to be_empty
      expect(footer.css("> p")[3].css("a").map { |link| [ link.text, link["href"] ] }).to eq([ [ "Zeta Base", "https://zeta.test/about" ] ])
    end

    it "shows nothing for a type whose source supplies no notice (AC-2.2)", :other_catalog do
      get collection_path

      expect_the_footer("with a type that has no notice")
    end

    it "shows a line two types supply once (AC-2.4)" do
      register_notice_catalog("zeta", notice_line("Data from Zeta Base."), notice_line(attribution, "Scryfall" => "https://scryfall.com"))
      get collection_path

      expect(lines).to eq([ notice, attribution, "Data from Zeta Base." ])
    end

    it "shows a line as escaped text, and as text alone when its link is unsafe", :aggregate_failures do
      register_notice_catalog("zeta", notice_line(%(Zeta <b>bold</b> & "quoted"), "bold" => "javascript:alert(1)"))
      get collection_path

      expect(lines.last).to eq(%(Zeta <b>bold</b> & "quoted"))
      expect(response.body).to include("Zeta &lt;b&gt;bold&lt;/b&gt; &amp; &quot;quoted&quot;")
      expect(footer.css("a").size).to eq(2)
      expect(response.body).not_to include("javascript:")
    end

    it "has no footer element when no type supplies a notice (AC-2.3)", :aggregate_failures do
      with_catalog_sources("other" => "OtherCatalogSource") { get more_path }

      expect(response).to have_http_status(:ok)
      expect(footers).to be_empty
      expect(html.at_css("body")["class"]).to eq("c-shell")
    end
  end

  describe "under the scanner's Content-Security-Policy" do
    def policy = response.headers["Content-Security-Policy"].split(";").map(&:split).to_h { |name, *sources| [ name, sources ] }

    # Spec 007 AC-2.4, as ScannerPage sets it; only the nonce's value changes between requests.
    def expect_the_scanner_policy
      expect(policy).to match(
        "default-src" => [ "'self'" ], "script-src" => [ "'self'", "'wasm-unsafe-eval'", a_string_matching(/\A'nonce-[^']+'\z/) ],
        "worker-src" => [ "'self'", "blob:" ], "connect-src" => [ "'self'" ],
        "img-src" => [ "'self'", "data:", "blob:", "https://scryfall.com", "https://cards.scryfall.io", "https://svgs.scryfall.io" ],
        "style-src" => [ "'self'", "'unsafe-inline'" ], "font-src" => [ "'self'" ], "object-src" => [ "'none'" ],
        "frame-src" => [ "'none'" ], "base-uri" => [ "'self'" ], "form-action" => [ "'self'" ], "frame-ancestors" => [ "'self'" ])
    end

    before { sign_in_as(create(:user)) }

    it "is on the scanner page, which sends the policy it always sent (AC-4.2)", :aggregate_failures do
      get scanner_path

      expect_the_footer("scanner")
      expect_the_scanner_policy
      expect(footer.to_html).not_to match(/style=|nonce=|<script/)
    end

    context "with measurement mode on" do
      let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

      around do |example|
        corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
        Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
        example.run
      ensure
        Rails.configuration.x.scanner_measurement = nil
        FileUtils.remove_entry(corpus)
      end

      it "is on the measurement page and its replay page, under the same policy (AC-4.3)", :aggregate_failures do
        [ scanner_measurement_path, scanner_measurement_replay_path(label: "a") ].each do |path|
          get path
          expect(response).to have_http_status(:ok), path
          expect_the_footer(path)
          expect_the_scanner_policy
        end
      end
    end
  end
end
