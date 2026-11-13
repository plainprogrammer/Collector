require "rails_helper"

RSpec.describe "Scanner page", type: :request do
  let(:user) { create(:user, admin: true) }

  def csp = response.headers["Content-Security-Policy"].to_s.split(";").map(&:split).to_h { |name, *values| [ name, values ] }

  it "sends a signed-out visitor to sign in (AC-1.2)" do
    create(:user)
    get scanner_path
    expect(response).to redirect_to(new_session_path)
  end

  describe "when signed in" do
    before { sign_in_as(user) }

    it "loads the engine from this app's versioned path, with the shutter busy until it's ready (AC-2.2, AC-2.5)", :aggregate_failures do
      get scanner_path
      expect(response.body).to include('src="/ocr/v7.0.0/tesseract.min.js"', 'data-card-reader-engine-path-value="/ocr/v7.0.0"')
      expect(response.body).to match(/<button[^>]*c-scan__main[^>]*disabled[^>]*aria-busy="true"/)
      expect(response.body).to include('<meta name="turbo-visit-control" content="reload">', '<meta name="turbo-cache-control" content="no-cache">')
    end

    it "sends a strict policy with a fresh nonce for its own inline tags (AC-2.4)", :aggregate_failures do
      get scanner_path
      expect(csp["script-src"]).to match([ "'self'", "'wasm-unsafe-eval'", a_string_matching(/\A'nonce-[^']+'\z/) ])
      expect(csp.values_at("worker-src", "connect-src", "frame-src")).to eq([ [ "'self'", "blob:" ], [ "'self'" ], [ "'none'" ] ])
      nonce = csp["script-src"].last[/'nonce-(.+)'/, 1]
      expect(response.body).to include(%(nonce="#{nonce}"))
      get scanner_path
      expect(csp["script-src"].last).not_to eq("'nonce-#{nonce}'")
    end

    it "serves the detector from this app under the unchanged policy (AC-7.5)", :aggregate_failures do
      get scanner_path
      expect(response.body).to match(%r{"scanner/detector": "/assets/scanner/detector-[0-9a-f]+\.js"})
      expect(csp["script-src"].first(2)).to eq([ "'self'", "'wasm-unsafe-eval'" ])
    end

    it "keeps the policy off every other page and the engine with it (AC-2.3)", :aggregate_failures do
      [ collection_path, catalog_entries_path(q: "bolt"), more_path ].each do |path|
        get path
        expect(response.headers["Content-Security-Policy"]).to be_nil
        expect(response.body).not_to include("/ocr/", "nonce=")
      end
    end

    it "is linked from the main navigation and the collection page, marked current on the scanner (AC-8.1, AC-8.2)", :aggregate_failures do
      get collection_path
      html = Nokogiri::HTML5(response.body)
      expect(html.css(".c-appbar__nav a[href='#{scanner_path}']").map(&:text)).to eq([ "Scan" ])
      expect(html.css(".c-tabbar a[href='#{scanner_path}']").map { it.text.strip }).to eq([ "Scan" ])
      expect(html.css(".c-pagehead__actions a[href='#{scanner_path}']").map { it.text.strip }).to eq([ "Scan cards" ])
      expect(html.css("a[href='#{scanner_path}']").map { it["data-turbo-prefetch"] }).to eq(%w[false false false])
      Scanner::Sitting.create!(account: user.account, condition: "near_mint")
      get new_scanner_sitting_ending_path
      html = Nokogiri::HTML5(response.body)
      expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Scan" ])
      expect(html.css(".c-tabbar a[aria-current=page]").map { it.text.strip }).to eq([ "Scan" ])
      get scanner_path
      expect(Nokogiri::HTML5(response.body).css("nav")).to be_empty # decision 24
    end

    describe "the one-screen page (spec 082)" do
      it "shows the end of a sitting's summary on the after-add line with a link to the collection (AC-5.6)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        Scanner::Sitting.add!(account: user.account, printing: entry, finish: "nonfoil", reading_key: "a" * 32)
        post scanner_sitting_ending_path
        follow_redirect!
        body = Nokogiri::HTML5(response.body)
        expect(body.at("#scanner_added_text").text).to eq("Added 1 card in this sitting.")
        expect(body.at("#scanner_added_action a").text).to eq("Open your collection")
        expect(body.at("#scanner_added_action a")["href"]).to eq(collection_path)
        expect(body.at(".c-scan__line--added")["hidden"]).to be_nil
      end

      it "shows a flash from a page the scanner was left for on the after-add line, once (AC-6.4)", :aggregate_failures do
        lot = create(:lot, account: user.account, quantity: 1)
        patch lot_path(lot, return_to: scanner_path), params: { lot: { quantity: "2" } }
        follow_redirect!
        expect(Nokogiri::HTML5(response.body).at("#scanner_added_text").text).to be_present
        get scanner_path
        expect(Nokogiri::HTML5(response.body).at("#scanner_added_text").text).to be_empty
      end

      it "leaves the after-add line empty and hidden on a plain visit", :aggregate_failures do
        get scanner_path
        body = Nokogiri::HTML5(response.body)
        expect(body.at("#scanner_added_text").text).to be_empty
        expect(body.at(".c-scan__line--added")["hidden"]).to eq("")
      end

      it "renders the focused shell with its bars, stage, pane and two sheets (AC-1.1, AC-1.3, AC-1.5, AC-2.2, decision 16)", :aggregate_failures do
        get scanner_path
        body = Nokogiri::HTML5(response.body)
        expect(body.at("body")["class"].split).to include("c-shell", "c-shell--untabbed", "c-shell--focused")
        expect(body.css("#appbar, .c-tabbar, footer.c-footer, body > #status")).to be_empty
        expect(body.at("main.c-scan h1.c-sr").text).to eq("Scan a card")
        expect(body.css(".c-scan__top > *").map { it["class"].to_s[/c-scan__\w+/] }).to eq(%w[c-scan__back c-scan__sitting])
        expect(body.at(".c-scan__back")["href"]).to eq(collection_path)
        expect(body.at(".c-scan__dest").text.squish).to eq("Adding to No location")
        expect(body.css(".c-scan__done")).to be_empty # no sitting open (spec 009 AC-3.7)
        expect(body.css(".c-scan__bottom > *").map { it["id"] || it["class"].to_s[/c-scan__\w+/] }).to eq(%w[scanner_count c-scan__main c-scan__torch])
        expect(body.at("#scanner_count")["aria-label"]).to eq("0 added. Show this sitting's cards.")
        expect(body.at("dialog#scanner_destination_sheet .c-sheet__title").text).to eq("Adding to")
        expect(body.at("dialog#scanner_list_sheet #scanner-sitting-heading").text).to eq("This sitting: 0 cards")
        expect(body.css("dialog .c-sheet__foot").size).to eq(2)
        expect(body.at("main.c-scan noscript").inner_html).to include("The scanner needs JavaScript", "c-sheet__foot")
      end
    end
  end
end
