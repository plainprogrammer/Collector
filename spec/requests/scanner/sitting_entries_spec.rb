require "rails_helper"

RSpec.describe "Scanner adds", type: :request do
  let(:user) { create(:user) }
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:printing) do
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end
  let(:key) { "a" * 32 }

  before { sign_in_as(user) }

  def add(finish: "foil", reading_key: key, to: printing.external_key)
    post scanner_sitting_entries_path, params: { entry: { printing: to, finish:, reading_key: } },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  it "adds one copy, clears the reading, lists it and announces it (AC-1.2, AC-1.3, AC-3.1, AC-3.2)", :aggregate_failures do
    add
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to match(%r{<turbo-stream action="update" target="scanner_result"><template>\s*</template></turbo-stream>})
    expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">', "This sitting: 1 card")
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(user.account.lots.sole).to have_attributes(entry: printing, finish: "foil", quantity: 1, condition: nil)
  end

  it "leaves the finish out of the message for a printing with none listed (AC-1.3)" do
    MTG::Printing.find_by!(catalog_entry_id: printing.id).update!(finishes: [])
    add(finish: "")
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123) to your collection.")
  end

  it "adds nothing for a reading already added, and answers as if it had just succeeded (AC-1.5)", :aggregate_failures do
    add
    add(finish: "nonfoil")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "says so when the reading's add was undone, or its copy changed, adding nothing (AC-1.5)", :aggregate_failures do
    add
    Scanner::SittingEntry.sole.undo!
    add
    expect(response.body).to include("You added this card, then undid it. Scan it again to add it.")
    add(reading_key: "b" * 32)
    user.account.lots.sole.destroy!
    add(reading_key: "b" * 32)
    expect(response.body).to include("You added this card, and it has since changed in your collection.")
    expect(user.account.lots).to be_empty
  end

  it "refuses at the lot cap, adding nothing (AC-1.6)", :aggregate_failures do
    create(:lot, account: user.account, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY)
    add
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    expect(Scanner::SittingEntry.count).to eq(0)
  end

  it "refuses a missing or malformed key, an unknown or retired printing and a finish it doesn't come in (Error Scenarios)", :aggregate_failures do
    retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
    [ { reading_key: "" }, { reading_key: "XYZ" }, { to: "nope" }, { to: retired.external_key }, { finish: "etched" } ].each do |change|
      add(**change)
      expect(response).to have_http_status(:unprocessable_content), change.inspect
      expect(CGI.unescapeHTML(response.body)).to include("That card couldn't be added. Scan it again.")
    end
    expect(user.account.lots).to be_empty
  end

  it "adds to the signed-in account's own sitting only (AC-3.8)", :aggregate_failures do
    other = create(:user).account
    Scanner::Sitting.add!(account: other, printing:, finish: "nonfoil", reading_key: key)
    add
    expect(other.lots.sole.finish).to eq("nonfoil")
    expect(user.account.scanner_sitting.entries.sole.finish).to eq("foil")
  end

  it "sends a signed-out visitor to sign in" do
    delete session_path
    add
    expect(response).to redirect_to(new_session_path)
  end
end
