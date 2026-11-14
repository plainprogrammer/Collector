require "rails_helper"

# Spec 088 decisions 3, 4, 15: the selection frame for one card, which "All printings" and "Show 20 more" request.
RSpec.describe "The scanner's selection frame", type: :request do
  let(:key) { "f" * 32 }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let!(:matched) { create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom", name: "March of the Machine"), number: "123")).entry }

  before do
    24.times { |i| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "s#{i}", name: "Set #{i}"), number: i.to_s)) }
    sign_in_as(create(:user))
  end

  def frame(**params)
    get scanner_printings_path(card: identity.external_key, key:, match: matched.external_key, band: "guess", **params), headers: { "Turbo-Frame" => "scanner_selection" }
    Nokogiri::HTML5(response.body)
  end

  def tags(page) = page.css(".c-scanpane__card .c-tag").map(&:text)

  it "answers the card's printings in the selection frame, the named one first, 20 at a time with a more item (AC-3.1, AC-3.10)", :aggregate_failures do
    page = frame
    expect(response).to have_http_status(:ok)
    expect(page.css("turbo-frame#scanner_selection .c-scanpane__item").size).to eq(21) # 20 and the more item
    expect(page.at_css(".c-scanpane__item--more").text).to include("5 more printings")
    expect(page.at_css(".c-scanpane__card:not([hidden]) .c-scanpane__position").text).to eq("1 of 25 printings")
    expect(page.at_css(".c-scanpane__row")["data-selection-focus"]).to eq("true")
    more = page.css(".c-scanpane__card").last.at_css("a.c-btn")
    expect(more.text).to eq("Show 20 more")
    expect(more["href"]).to include("limit=40", "current=")
  end

  it "answers every printing at a raised limit, centred on the current one (AC-3.10)", :aggregate_failures do
    current = Catalog::Entry.where(catalog_identity_id: identity.id).order(:id).last.external_key
    page = frame(limit: 40, current:)
    expect(page.css(".c-scanpane__item--more")).to be_empty
    expect(page.css(".c-scanpane__item").size).to eq(25)
    expect(page.css(".c-scanpane__item").map { it["aria-current"] }.compact.size).to eq(1)
  end

  it "ends a row at the cap with no more item and no Show 20 more link (decision 4)", :aggregate_failures do
    stub_const("Scanner::Selection::MAX", 20)
    page = frame(limit: 20)
    expect(page.css(".c-scanpane__item").size).to eq(20)
    expect(page.css(".c-scanpane__item--more")).to be_empty
    expect(page.at_css(".c-scanpane__card:not([hidden]) .c-scanpane__position").text).to eq("1 of 25 printings")
    expect(response.body).not_to include("Show 20 more")
  end

  it "reads a band outside the closed list as a guess (decision 15)", :aggregate_failures do
    frame(band: "<b>x</b>")
    expect(response.body).to include("Printing not confirmed. Swipe to check.")
    expect(response.body).not_to include("<b>x</b>")
  end

  it "puts the printings of the read set, then of the read number, after the named one (AC-3.1, spec 009 AC-2.2)" do
    expect(tags(frame(set: "s7", number: "3")).first(3)).to eq([ "MOM · 123", "S7 · 7", "S3 · 3" ])
  end

  it "lists the confident artwork's printings first, then the read set's and number's (spec 011 AC-7.5)", :aggregate_failures do
    art = "aaaaaaaa-0000-4000-8000-000000000001"
    s9 = Catalog::Entry.joins(:set).find_by!(catalog_sets: { code: "s9" })
    MTG::Printing.find_by!(catalog_entry_id: s9.id).update!(illustration_id: art)

    expect(tags(frame(set: "s7", number: "3", artwork: art)).first(3)).to eq([ "MOM · 123", "S9 · 9", "S7 · 7" ])
    expect(tags(frame(set: "s7", number: "3", artwork: "not-an-artwork")).first(3)).to eq([ "MOM · 123", "S7 · 7", "S3 · 3" ])
  end

  it "marks the foil button when the reading suggested foil (AC-4.3)" do
    page = frame(finish_hint: "foil")
    expect(page.css(".c-scanpane__card:not([hidden]) .c-scanpane__add button").map { it.text.strip }).to eq([ "Add nonfoil", "Add foil · read from the card" ])
  end

  it "answers 404 for a malformed key or an unknown card, as before", :aggregate_failures do
    get scanner_printings_path(card: identity.external_key, key: "nope"), headers: { "Turbo-Frame" => "scanner_selection" }
    expect(response).to have_http_status(:not_found)
    get scanner_printings_path(card: "missing", key:), headers: { "Turbo-Frame" => "scanner_selection" }
    expect(response).to have_http_status(:not_found)
  end

  it "needs a sign-in" do
    delete session_path
    get scanner_printings_path(card: identity.external_key, key:)
    expect(response).to redirect_to(new_session_path)
  end
end
