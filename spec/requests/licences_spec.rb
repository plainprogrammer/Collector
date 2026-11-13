require "rails_helper"
require "tmpdir"

# Spec 087 Story 1, Story 3 and Story 4 at the page: the third-party licences, for everyone. Stand-in components (the
# `third_party_licences` helper) show each kind of row; the real bundle and manifest are read by the examples that say so.
RSpec.describe "The third-party licences page", type: :request do
  let(:page) { Nokogiri::HTML5(response.body) }

  def component(name, **more)
    Collector::ThirdPartyLicences::Component.new(name:, version: "1.0", identifiers: [ "MIT" ], home: nil, copyright: nil, texts: [], note: nil, **more)
  end

  def section(*components, key: :gems) = Collector::ThirdPartyLicences::Section.new(key:, title: Collector::ThirdPartyLicences::TITLES.fetch(key), components:)

  def row(name) = page.css("li.c-licences__row").find { it.at_css(".c-licences__name").text == name }

  describe "who can read it" do
    before { third_party_licences([ section(component("example")) ]) }

    it "answers a signed-in collector with the application header, the tab bar and the footer (AC-1.1)", :aggregate_failures do
      sign_in_as(create(:user))

      get licences_path

      expect(response).to have_http_status(:ok)
      expect(page.at_css("h1").text).to eq("Third-party licences")
      expect(page.at_css("header.c-appbar nav.c-appbar__nav")).to be_present
      expect(page.at_css("nav.c-tabbar")).to be_present
      expect(page.at_css("footer.c-footer")).to be_present
    end

    shared_examples "a visitor's page" do
      it "answers with the brand-only header and the footer, and no redirect (AC-1.2)", :aggregate_failures do
        create(:user)

        get licences_path

        expect(response).to have_http_status(:ok)
        expect(page.at_css("header.c-appbar")).to be_present
        expect(page.at_css("header.c-appbar nav")).to be_nil
        expect(page.at_css("footer.c-footer")).to be_present
      end
    end

    context "with the open catalog off" do
      it_behaves_like "a visitor's page"
    end

    context "with the open catalog on", :public_catalog do
      it_behaves_like "a visitor's page"
    end

    it "answers before the first user exists, not with a redirect to sign-up (AC-1.3)" do
      get licences_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "the page's opening" do
    let(:sections) { Collector::ThirdPartyLicences::TITLES.keys.each_with_index.map { |key, index| section(*Array.new(index + 1) { component("#{key}-#{it}") }, key:) } }

    before { third_party_licences(sections) }

    it "says what is free software and that the rest ships under its own licence, with the AGPL-3.0 link (AC-1.4)", :aggregate_failures do
      get licences_path

      link = page.at_css("main p a")
      expect(link.text).to eq("AGPL-3.0")
      expect([ link["href"], link["rel"] ]).to eq([ Collector::BuildFacts::LICENCE_URL, "noopener" ])
      expect(page.css("main p").first.text).to include("ships in the image under its own licence")
    end

    it "says Ruby and the operating system's packages carry their notices in the image (AC-1.4)" do
      get licences_path

      expect(page.css("main p")[1].text).to include("Ruby", "operating system", "/usr/share/doc/<package>/copyright")
    end

    it "has the five sections in order, each heading with its count (AC-1.4)" do
      get licences_path

      expect(page.css("main h2").map { it.text.squish }).to eq([ "JavaScript 1", "OCR engine 2", "Fonts 3", "Icons 4", "Ruby gems 5" ])
    end

    it "has the page's one licence line once (AC-2.5)" do
      get licences_path

      expect(page.css("footer.c-footer p").count { it.text.include?("is free software under the") }).to eq(1)
    end
  end

  describe "a row" do
    let(:script) { "<script>alert('x')</script> & <b>bold</b>" }

    it "is a closed disclosure with each text escaped under its file name (AC-1.5, AC-1.7)", :aggregate_failures do
      third_party_licences([ section(component("texty", texts: [ [ "MIT-LICENSE", script ], [ "BSDL", "second" ] ], copyright: "Copyright 2026 Someone")) ])

      get licences_path

      details = row("texty").at_css("details.c-licences__details")
      expect(details["open"]).to be_nil
      expect(details.css("h3.c-licences__file").map(&:text)).to eq(%w[MIT-LICENSE BSDL])
      expect(details.css("pre.c-licences__text").map(&:text)).to eq([ script, "second" ])
      expect(details.text).to include("Copyright 2026 Someone")
      expect(response.body).to include("&lt;script&gt;alert")
      expect(response.body).not_to include("<script>alert")
    end

    it "shows name, version and identifiers in its heading, and a note after them (AC-1.5)" do
      third_party_licences([ section(component("noted", version: "7.0.0", identifiers: [ "MIT", "Ruby" ], note: "as the package declares")) ])

      get licences_path

      expect(row("noted").at_css(".c-licences__meta").text).to eq("7.0.0 · MIT, Ruby (as the package declares)")
    end

    it "has no disclosure and says the text is not found when it has none (AC-4.1)", :aggregate_failures do
      third_party_licences([ section(component("bare", home: "https://bare.test")) ])

      get licences_path

      expect(row("bare").at_css("details")).to be_nil
      expect(row("bare").at_css("p.c-licences__missing").text).to eq("Licence text not found")
      expect(row("bare").at_css("a")["href"]).to eq("https://bare.test")
    end

    it "links a home with rel noopener and no target (AC-1.5)", :aggregate_failures do
      third_party_licences([ section(component("homed", home: "https://homed.test/path", texts: [ [ "LICENSE", "text" ] ])) ])

      get licences_path

      link = row("homed").at_css("details a")
      expect([ link["href"], link["rel"], link["target"] ]).to eq([ "https://homed.test/path", "noopener", nil ])
    end

    it "has no home link for a gem whose homepage is not an absolute http address (AC-4.4)", :aggregate_failures do
      dir = Pathname(Dir.mktmpdir("licences-page"))
      specs = [ "javascript:alert(1)", "", "/relative" ].each_with_index.map { |home, index| stand_in_gem(dir, name: "odd#{index}", homepage: home) }
      third_party_licences([ section(*Collector::ThirdPartyLicences.gem_components(specs)) ])

      get licences_path

      expect(response).to have_http_status(:ok)
      expect(page.css("li.c-licences__row a")).to be_empty
    ensure
      FileUtils.remove_entry(dir)
    end

    it "answers 200 and shows each gem's files under their names, one row's trouble leaving the others (AC-4.3)", :aggregate_failures do
      dir = Pathname(Dir.mktmpdir("licences-page"))
      specs = [ stand_in_gem(dir, name: "fine", files: { "MIT-LICENSE" => "mit", "BSDL" => "bsd" }), stand_in_gem(dir, name: "big", files: { "LICENSE" => "x" * (1.megabyte + 1) }) ]
      third_party_licences([ section(*Collector::ThirdPartyLicences.gem_components(specs)) ])

      get licences_path

      expect(row("fine").css("h3.c-licences__file").map(&:text)).to eq(%w[BSDL MIT-LICENSE])
      expect(row("big").at_css("p.c-licences__missing")).to be_present
    ensure
      FileUtils.remove_entry(dir)
    end
  end

  describe "what the request costs" do
    before { third_party_licences([ section(component("example", texts: [ [ "LICENSE", "text" ] ])) ]) }

    it "runs no query for a visitor (AC-1.8)" do
      create(:user)

      expect(count_queries { get licences_path }).to eq(0)
    end

    it "runs no more queries for a collector than another signed-in page with the same header and footer (AC-1.8)" do
      sign_in_as(create(:user))
      get more_path
      get licences_path

      expect(count_queries { get licences_path }).to be <= count_queries { get more_path }
    end
  end

  describe "the real list" do
    it "is at most 1 MiB of HTML, whatever the bundle holds (AC-1.9)" do
      get licences_path

      RSpec.configuration.reporter.message("licences page: #{response.body.bytesize} bytes")
      expect(response.body.bytesize).to be <= 1.megabyte
    end

    it "lists the OCR engine and the JavaScript the gems serve with their texts (AC-3.1, AC-3.2)", :aggregate_failures do
      get licences_path

      expect(row("tesseract.js").at_css(".c-licences__meta").text).to eq("7.0.0 · Apache-2.0")
      expect(row("tesseract.js").css("h3.c-licences__file").map(&:text)).to eq([ "LICENSE.md", "Bundled libraries" ])
      expect(row("tesseract.js-core").at_css(".c-licences__meta").text).to eq("7.0.0 · Apache-2.0")
      expect(row("Turbo").at_css(".c-licences__meta").text).to eq("8.0.23 (turbo-rails 2.0.23) · MIT")
      expect(row("Turbo").text).to include("37signals")
      expect(row("Stimulus").at_css(".c-licences__meta").text).to eq("1.3.4 (stimulus-rails) · MIT")
      expect(row("Turbo").css("h3.c-licences__file").map(&:text)).to include("MIT-LICENSE")
    end

    it "shows the language data as declared with no text, the fonts and the icons with their notices (AC-3.3, AC-3.5, AC-4.2)", :aggregate_failures do
      get licences_path

      expect(row("@tesseract.js-data/eng").at_css(".c-licences__meta").text).to eq("1.0.0 · MIT (as the package declares)")
      expect(row("@tesseract.js-data/eng").at_css("p.c-licences__missing").text).to eq("Licence text not found")
      expect(row("@tesseract.js-data/eng").at_css("a")["href"]).to be_present
      expect([ "Fraunces", "IBM Plex Sans", "IBM Plex Mono" ].map { row(it).at_css(".c-licences__meta").text }).to all(eq("5.3.0 (Fontsource) · OFL-1.1"))
      expect(row("Fraunces").text).to include("Copyright 2020 The Fraunces Project Authors")
      expect(row("IBM Plex Sans").text).to include("Copyright 2019 IBM Corp. All rights reserved.")
      expect(row("IBM Plex Mono").text).to include("Copyright 2017 IBM Corp. All rights reserved.")
      expect(row("Lucide").text).to include("Cole Bemis", "Copyright (c) 2026 Lucide Icons and Contributors")
    end

    it "shows a gem's licence file under its file name, in the markup the image smoke test reads (AC-3.4)", :aggregate_failures do
      get licences_path

      expect(response.body).to include('c-licences__name">tesseract.js<', 'c-licences__file">MIT-LICENSE<', "Permission is hereby granted, free of charge")
      expect(row("rails").css("h3.c-licences__file").map(&:text)).to include("MIT-LICENSE")
    end
  end
end
