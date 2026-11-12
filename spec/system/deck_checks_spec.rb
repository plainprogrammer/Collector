require "rails_helper"

RSpec.describe "Deck checks", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo", format: "standard") }

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  def printing(name, type_line: "Basic Land — Plains")
    entry = create(:catalog_entry, identity: create(:catalog_identity, name:), name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "image_uris" => {} } ])
    entry
  end

  def clipped(selector) = page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].filter(el => el.scrollWidth > el.clientWidth + 1).length")

  it "moves keyboard focus to the results heading (AC-6.3)", :aggregate_failures do
    visit deck_path(deck)
    expect(tab_to_text("Check deck")).to be(true) # the link is reachable by Tab, and Enter is pressed on it
    page.send_keys(:enter)
    expect(page).to have_css("#deck-check-title:focus", text: "Deck check")
    expect(page.evaluate_script("document.getElementById('deck-check-title').tabIndex")).to eq(-1)
  end

  it "asks for the check again on Back instead of restoring a Turbo snapshot (AC-1.8)", :aggregate_failures do
    visit deck_path(deck)
    click_link "Check deck"
    expect(page).to have_text("Main: 0 cards; Standard needs at least 60.")
    page.execute_script("window.__sameDocument = true") # Turbo visits keep the document; a full page load would drop this
    create_lot_in_zone(deck, "main", entry: printing("Plains"), quantity: 60)
    click_link "Edit deck"
    wait_for_turbo_idle
    page.go_back
    expect(page).to have_text("Main: 60 cards; Standard needs at least 60.")
    expect(page.evaluate_script("window.__sameDocument")).to be(true) # still the same document, so Turbo did the Back
  end

  it "puts the results before the zones in reading order (AC-6.3)" do
    visit deck_check_path(deck)
    follows = "document.getElementById('deck-check-title').compareDocumentPosition(document.querySelector('.c-zone')) & Node.DOCUMENT_POSITION_FOLLOWING"
    expect(page.evaluate_script("!!(#{follows})")).to be(true)
  end

  it "fits a phone, in both themes, with long names (AC-6.1, 6.4)", :aggregate_failures do
    long = "N" * 60
    create_lot_in_zone(deck, "main", entry: printing(long, type_line: "Instant"), quantity: 5)
    deck.zone("main").update_columns(name: "Z" * 60) # a zone's shown name is a copy, so a long one is a fixture, not a rename flow
    visit deck_path(deck)
    expect(open_in_viewport_frame(deck_check_path(deck), viewport: 360, ready: "#deck-check-title")).to eq(360)
    within_narrow_frame do
      %w[light dark].each do |theme|
        set_theme(theme)
        expect([ page_fits_sideways?, clipped(".c-check__text, .c-check__status, .c-item__actions .c-btn") ]).to eq([ true, 0 ])
      end
    end
  end

  it "says pass or fault in words with an icon on every row, never by colour alone (AC-6.2)", :aggregate_failures do
    create_lot_in_zone(deck, "main", entry: printing("Plains"), quantity: 58)
    visit deck_check_path(deck)
    rows = all(".c-check__row--fault .c-check__status")
    expect(rows.map(&:text)).to all(be_in([ "Short", "Over", "Over the limit", "Owned and proxy" ]))
    expect(page).to have_css(".c-check__status svg", count: page.all(".c-check__status").size)
  end
end
