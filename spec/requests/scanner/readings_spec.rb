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

    it "shows what was read and the candidates, the collector-line match first (AC-3.1, AC-3.2)", :aggregate_failures do
      read("Lightnlng Bo1t", "R 0123\nMOM • EN")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_result">', "Lightnlng Bo1t", "R 0123")
      expect(response.body).to include("Matched one printing", "Matched by its collector line", "MOM · 123", "March of the Machine")
    end

    it "marks a candidate found by its name alone as a guess at the printing (AC-2.1, AC-5.1)", :aggregate_failures do
      read("Lightning Bolt", "")
      expect(response.body).to include("Printing not confirmed", "Matched by its name")
      expect(response.body).not_to include("Matched by its collector line")
    end

    it "says when the collector line matches several printings or none (AC-3.3)", :aggregate_failures do
      create(:mtg_printing, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: mom, number: "123"))
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(response.body).to include("Several printings").and include("Lightning Bolt")
      read("Lightning Bolt", "R 0999\nMOM • EN")
      expect(response.body).to include("No printing")
    end

    it "offers an add button per finish carrying the reading key, and no 'coming' note (AC-1.1, AC-8.4)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM • EN")
      html = Nokogiri::HTML5(response.body)
      forms = html.css("form.c-scanner__add")
      expect(forms.map { it.at_css("input[name='entry[finish]']")["value"] }).to eq(%w[nonfoil foil])
      expect(forms.map { it.at_css("input[name='entry[reading_key]']")["value"] }.uniq).to eq([ key ])
      expect(forms.map { it["data-rank"] }).to eq(%w[1 1])
      expect(html.css("form.c-scanner__add button").map { it["aria-label"] })
        .to eq([ "Add Lightning Bolt MOM · 123 Nonfoil", "Add Lightning Bolt MOM · 123 Foil" ])
      expect(response.body).not_to include("Adding cards from the scanner is coming")
    end

    it "offers a single Add for a one-finish printing (AC-1.1)" do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil])
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }).to eq([ "Add" ])
    end

    it "offers Other printings on every candidate, with what was read (AC-2.1)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM • EN")
      link = Nokogiri::HTML5(response.body).at_css("a[data-turbo-frame=scanner_printings]")
      expect(link.text).to eq("Other printings")
      expect(Rack::Utils.parse_query(URI(link["href"]).query)).to include("card" => bolt.identity.external_key, "key" => key, "set" => "MOM", "number" => "123")
    end

    it "marks the Foil button when the separator reads as the foil marker, adding nothing by itself (AC-6.5)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM ★ EN")
      labels = Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }
      expect(labels).to eq([ "Nonfoil", "Foil · read from the card" ])
      expect(Lot.count).to eq(0)
    end

    it "turns away a reading without a well-formed key" do
      read("Lightning Bolt", "", key: "nope")
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "says when nothing could be read" do
      read("", "")
      expect(response.body).to include("Nothing could be read")
    end

    it "turns away text over 2,000 characters", :aggregate_failures do
      read("a" * 2_001, "")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That reading was too long to use")
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
    end

    it "ignores artworks with art matching off (AC-1.1)", :aggregate_failures do
      post scanner_readings_path, params: { reading: { name_text: "", collector_text: "", key:, artworks: [ { id: "aaaaaaaa-0000-4000-8000-000000000001", distance: 1 } ] } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("Nothing could be read")
    end
  end

  it "says the catalog isn't ready while the name index is empty (AC-3.8)" do
    read("Lightning Bolt", "")
    expect(response.body).to include("The card catalog isn't ready yet")
  end

  it "sends an expired session to sign in" do
    delete session_path
    read("Lightning Bolt", "")
    expect(response).to redirect_to(new_session_path)
  end
end
