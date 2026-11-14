require "rails_helper"

RSpec.describe "Scanner readings", type: :request do
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let!(:bolt) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end

  let(:key) { "f" * 32 }

  before { sign_in_as(create(:user)) }

  def read(name_text, collector_text, key: self.key)
    post scanner_readings_path, params: { reading: { name_text:, collector_text:, key: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  context "when the name index is built" do
    before { Catalog::NameIndex.new("mtg").rebuild }

    def pane = Nokogiri::HTML5(response.body)

    it "answers a collector-line match with a selection frame of its printings, the match first, success band in the first panel (AC-2.1, AC-3.1)", :aggregate_failures do
      read("Lightnlng Bo1t", "R 0123\nMOM • EN")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_result">')
      expect(pane.css("turbo-frame#scanner_selection.c-scanpane__body").size).to eq(1)
      items = pane.css(".c-scanpane__item")
      expect(items.first["aria-current"]).to eq("true")
      expect(items.drop(1).map { it["aria-current"] }).to all(be_nil)
      panels = pane.css(".c-scanpane__card")
      expect(panels.map { it["hidden"] }).to eq([ nil, *Array.new(panels.size - 1, "hidden") ])
      template = panels.first.at_css("template[data-band]")
      expect(template["data-band"]).to eq("c-band--success")
      expect(template.inner_html).to include("Matched by its collector line", "Printing 1 of 1: Lightning Bolt, March of the Machine, MOM · 123.")
      expect(panels.first.at_css(".c-scanpane__position").text).to eq("1 of 1 printing")
      expect(response.body).not_to include("What the scanner read", "c-scanner__candidate", "scanner_printings")
    end

    it "marks a name-only match of the right card as a printing guess (AC-2.2)", :aggregate_failures do
      read("Lightning Bolt", "")
      template = pane.at_css(".c-scanpane__card template[data-band]")
      expect(template["data-band"]).to eq("c-band--warning")
      expect(template.inner_html).to include("Printing not confirmed. Swipe to check.")
      expect(response.body).not_to include("Matched by its name")
    end

    it "reads 'Lightning' as a name-only, not strong match, so the system examples that draw it get the possible-cards row (execution note)", :aggregate_failures do
      read("Lightning", "")
      template = pane.at_css(".c-scanpane__card template[data-band]")
      expect(template.inner_html).to include("Not sure of this card. Check it against your capture.")
      expect(pane.css(".c-scanpane__row").first.ancestors(".c-scanpane__rowwrap").first["aria-label"]).to eq("Possible cards")
    end

    it "holds only the matched card's printings when the scanner is sure, not the other candidate cards (AC-3.8)", :aggregate_failures do
      create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Lightning Helix"), name: "Lightning Helix", set: mom, number: "7"))
      Catalog::NameIndex.new("mtg").rebuild
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(pane.css(".c-scanpane__name").map(&:text)).to eq([ "Lightning Bolt" ])
      expect(response.body).not_to include("Lightning Helix")
    end

    it "answers a name that is not strong with the candidate cards, the question band and All printings per panel (AC-2.3, AC-3.8, AC-3.9)", :aggregate_failures do
      read("Lightnlng Bo1t", "")
      template = pane.at_css(".c-scanpane__card template[data-band]")
      expect(template["data-band"]).to eq("c-band--warning")
      expect(template.inner_html).to include("Not sure of this card. Check it against your capture.")
      expect(pane.at_css(".c-scanpane__rowwrap")["aria-label"]).to eq("Possible cards")
      expect(pane.at_css(".c-scanpane__position").text).to match(/\A1 of [12] possible cards?\z/)
      pane.css(".c-scanpane__card").each do |panel|
        link = panel.css("a").find { it.text.strip == "All printings" }
        expect(link["href"]).to include("match=", "band=guess")
        expect(link["data-turbo-frame"]).to eq("scanner_selection")
      end
    end

    it "puts a candidate's image in the row item, with no class or style of its own (spec 019 AC-1.4)", :aggregate_failures do
      bolt.update!(image_url: "https://cards.scryfall.io/normal/front/b/o/bolt.jpg")
      read("Lightning Bolt", "")
      image = pane.at_css(".c-scanpane__item > img")
      expect(image&.[]("src")).to eq(bolt.image_url)
      expect([ image["class"], image["style"] ]).to eq([ nil, nil ])
    end

    it "gives every panel one add button per finish, named for the printing, with the star on a special finish (AC-4.2)", :aggregate_failures do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil foil])
      read("Lightning Bolt", "R 0123\nMOM • EN")
      forms = pane.css(".c-scanpane__card:not([hidden]) .c-scanpane__add")
      expect(forms.map { it.at_css("button").text.strip }).to eq([ "Add nonfoil", "Add foil" ])
      expect(forms.map { it.at_css("button")["aria-label"] }).to eq([ "Add Lightning Bolt MOM · 123 Nonfoil", "Add Lightning Bolt MOM · 123 Foil" ])
      expect(forms.map { it["data-turbo-frame"] }.uniq).to eq([ "_top" ])
      expect(forms.map { it.css("svg").size }).to eq([ 0, 1 ])
    end

    it "carries the reading key and the rank on every add, and says nothing about adding being 'coming' (AC-4.1, AC-8.4)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM • EN")
      forms = pane.css(".c-scanpane__card:not([hidden]) form.c-scanpane__add")
      expect(forms.map { it.at_css("input[name='entry[finish]']")["value"] }).to eq(%w[nonfoil foil])
      expect(forms.map { it.at_css("input[name='entry[reading_key]']")["value"] }.uniq).to eq([ key ])
      expect(forms.map { it["data-rank"] }.uniq).to eq([ "1" ])
      expect(response.body).not_to include("Adding cards from the scanner is coming")
    end

    it "offers a single Add for a one-finish printing (AC-4.2)" do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil])
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(pane.css(".c-scanpane__card:not([hidden]) .c-scanpane__add button").map { it.text.strip }).to eq([ "Add" ])
    end

    it "relabels the foil button when the foil marker was read, and adds nothing more (AC-4.3)", :aggregate_failures do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil foil])
      read("Lightning Bolt", "R 0123\nMOM ★ EN")
      forms = pane.css(".c-scanpane__card:not([hidden]) .c-scanpane__add")
      expect(forms.map { it.at_css("button").text.strip }).to eq([ "Add nonfoil", "Add foil · read from the card" ])
      expect(Lot.count).to eq(0)
    end

    it "writes a card named with markup as text everywhere the answer says it (AC-6.3)", :aggregate_failures do
      bolt.update!(name: "Bolt <script>alert(1)</script>")
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end

    it "says 'Nothing could be read' on the status line and opens no pane (AC-6.1)", :aggregate_failures do
      read("", "")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_status_text">', "Nothing could be read. Line the card up with the guide and capture it again.")
      expect(response.body).not_to include('target="scanner_result"', 'target="status"')
    end

    it "says 'No card matches' on the status line when text was read and nothing matches (AC-6.1)", :aggregate_failures do
      read("Zzzzzzzz Qqqqqq", "")
      expect(response.body).to include('target="scanner_status_text"', "No card matches what was read. Line the card up with the guide and capture it again.")
    end

    it "turns away a reading without a well-formed key with an alert in the pane's status region, and no result (AC-6.2)", :aggregate_failures do
      read("Lightning Bolt", "", key: "nope")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="status"', "c-status__message--alert")
      expect(CGI.unescapeHTML(response.body)).to include("That reading couldn't be used. Capture the card again.")
      expect(response.body).not_to include('target="scanner_result"')
    end

    it "turns away text over 2,000 characters in the same alert, and no result (AC-6.2)", :aggregate_failures do
      read("a" * 2_001, "")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="status"', "c-status__message--alert", "That reading was too long to use")
      expect(response.body).not_to include('target="scanner_result"')
    end

    context "with art matching on (spec 011)", :art_matching do
      let(:art) { "aaaaaaaa-0000-4000-8000-000000000001" }

      before do
        MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(illustration_id: art)
        create(:mtg_artwork, illustration_id: art, entry: bolt)
      end

      def read_with_art(artworks, name_text: "Lightnlng Bo1t")
        post scanner_readings_path, params: { reading: { name_text:, collector_text: "", key:, artworks: } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "ranks with the artworks sent (AC-6.3)", :aggregate_failures do
        read_with_art([ { id: art, distance: 120 } ], name_text: "")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Lightning Bolt", "MOM · 123")
      end

      it "never refuses a reading for its art part (AC-6.1)", :aggregate_failures do
        read_with_art([ { id: "not-a-uuid", distance: 120 } ])
        expect(response).to have_http_status(:ok)
        read_with_art("x")
        expect(response).to have_http_status(:ok)
      end

      def html = Nokogiri::HTML5(response.body)

      it "says 'Matched by its artwork' in the band when the artwork belongs to one printing, and holds only that card's printings (AC-2.1, AC-3.8)", :aggregate_failures do
        create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Shock"), name: "Shock", set: mom, number: "9"))
        Catalog::NameIndex.new("mtg").rebuild
        read_with_art([ { id: art, distance: 150 } ], name_text: "Shock")

        template = html.at_css(".c-scanpane__card template[data-band]")
        expect(template["data-band"]).to eq("c-band--success")
        expect(template.inner_html).to include("Matched by its artwork")
        expect(html.css(".c-scanpane__name").map(&:text)).to eq([ "Lightning Bolt" ])
        expect(response.body).not_to include("The artwork matches a different card")
      end

      it "marks a shared artwork's printing as not confirmed (AC-2.2)", :aggregate_failures do
        create(:mtg_printing, illustration_id: art, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: create(:catalog_set, code: "m25"), number: "5"))
        read_with_art([ { id: art, distance: 150 } ], name_text: "")

        template = html.at_css(".c-scanpane__card template[data-band]")
        expect(template["data-band"]).to eq("c-band--warning")
        expect(template.inner_html).to include("Printing not confirmed. Swipe to check.")
      end

      it "says nothing about a weak artwork in the pane (decision 12)", :aggregate_failures do
        read_with_art([ { id: art, distance: 420 } ], name_text: "Lightning Bolt")
        expect(response.body).not_to include("Artwork looks similar", "Matched by its artwork", "Looks similar")
      end
    end

    it "ignores artworks with art matching off (AC-1.1)", :aggregate_failures do
      post scanner_readings_path, params: { reading: { name_text: "", collector_text: "", key:, artworks: [ { id: "aaaaaaaa-0000-4000-8000-000000000001", distance: 1 } ] } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("Nothing could be read")
    end
  end

  it "says the catalog isn't ready in the pane while the name index is empty (AC-6.2)", :aggregate_failures do
    read("Lightning Bolt", "")
    expect(response.body).to include('target="status"', "c-status__message--alert")
    expect(CGI.unescapeHTML(response.body)).to include("The card catalog isn't ready yet")
    expect(response.body).not_to include('target="scanner_result"')
  end

  it "sends an expired session to sign in" do
    delete session_path
    read("Lightning Bolt", "")
    expect(response).to redirect_to(new_session_path)
  end

  it "records each reading's art outcome in measurement mode only (spec 011 AC-9.3, FR-5)", :aggregate_failures do
    Catalog::NameIndex.new("mtg").rebuild
    Dir.mktmpdir do |dir|
      manifest = Pathname(dir).join("manifest.csv")
      manifest.write("file,set,number\nIMG_1.jpeg,mom,123\n")
      Rails.configuration.x.scanner_measurement = { manifest: manifest.to_s, dir: Pathname(dir).join("run").to_s }
      read("Lightning Bolt", "")
      expect(Scanner::MeasurementRun.current(framing: "full").readings.sole).to include("reading_key" => key, "tier" => "strong_name", "art_status" => nil)
    ensure
      Rails.configuration.x.scanner_measurement = nil
    end
    read("Lightning Bolt", "")
    expect(response).to have_http_status(:ok)
  end
end
