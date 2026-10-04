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
      expect(response.body).to match(/<button[^>]*c-scanner__shutter[^>]*disabled[^>]*aria-busy="true"/)
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
      get scanner_path
      html = Nokogiri::HTML5(response.body)
      expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Scan" ])
      expect(html.css(".c-tabbar a[aria-current=page]").map { it.text.strip }).to eq([ "Scan" ])
    end
  end
end
