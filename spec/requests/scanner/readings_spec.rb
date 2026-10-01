require "rails_helper"

RSpec.describe "Scanner readings", type: :request do
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let!(:bolt) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end

  before { sign_in_as(create(:user)) }

  def read(name_text, collector_text)
    post scanner_readings_path, params: { reading: { name_text:, collector_text: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  context "when the name index is built" do
    before { Catalog::NameIndex.new("mtg").rebuild }

    it "shows what was read and the candidates, the collector-line match first (AC-3.1, AC-3.2)", :aggregate_failures do
      read("Lightnlng Bo1t", "R 0123\nMOM • EN")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_result">', "Lightnlng Bo1t", "R 0123")
      expect(response.body).to include("Matched one printing", "Matched by its collector line", "MOM · 123", "March of the Machine")
    end

    it "says when the collector line matches several printings or none (AC-3.3)", :aggregate_failures do
      create(:mtg_printing, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: mom, number: "123"))
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(response.body).to include("Several printings").and include("Lightning Bolt")
      read("Lightning Bolt", "R 0999\nMOM • EN")
      expect(response.body).to include("No printing")
    end

    it "offers no way to add a card, and links to the catalog search (AC-3.10)", :aggregate_failures do
      read("Lightning Bolt", "")
      expect(response.body).not_to include("quick_add", "Add 1 ×")
      expect(response.body).to include("Adding cards from the scanner is coming", %(href="#{catalog_entries_path(q: "Lightning Bolt")}"))
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
