require "rails_helper"

RSpec.describe "The scanner's sitting", type: :system do
  let(:user) { create(:user) }
  let(:printing) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end

  before do
    printing
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(user)
  end

  def add_by_scanning
    show_synthetic_card
    click_on "Capture"
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
  end

  def close_sheet = find("dialog[open]").send_keys(:escape)

  it "survives signing out and resumes on the scanner, taking further adds (AC-3.3)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_button("1 added. Show this sitting's cards.")
    visit more_path
    click_on "Sign out"
    system_sign_in_as(user)
    visit scanner_path
    expect(page).to have_button("1 added. Show this sitting's cards.")
    add_by_scanning
    expect(page).to have_button("2 added. Show this sitting's cards.")
  end

  it "undoes an add in place, the camera still running (AC-4.1)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    page.execute_script("window.__marker = 'still here'")
    click_on "Undo"
    expect(page).to have_css("#scanner_added_text", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("document.activeElement.dataset.scanMain")).to eq("") # AC-5.3
    expect(user.account.lots).to be_empty
  end

  it "opens the list sheet with its live region empty after an Undo from the after-add line wrote into it (spec 082 decision 10)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    click_on "Undo"
    expect(page).to have_css("#scanner_added_text", text: "Removed 1 × Lightning Bolt")
    expect(page.evaluate_script("document.getElementById('scanner_list_status').textContent.trim()")).not_to be_empty # written while the sheet is closed
    open_sitting_list
    expect(page).to have_css("dialog#scanner_list_sheet[open]")
    expect(page.evaluate_script("document.getElementById('scanner_list_status').textContent.trim()")).to eq("")
  end

  def set_sitting(condition: nil, location: nil)
    open_destination unless page.has_css?("dialog#scanner_destination_sheet[open]", wait: 0)
    select condition, from: "Condition" if condition
    select location, from: "Location" if location
    click_on "Set"
  end

  def end_sitting
    click_on "Done"
    click_on "End sitting"
  end

  def list_heading = find("#scanner-sitting-heading", visible: :all).text(:all)

  describe "a sitting's place (spec 040)" do
    def entry_metas
      open_sitting_list
      all("#scanner_sitting li .c-list__meta").map { it.text.squish }
    end

    before do
      create(:location, account: user.account, name: "Blue binder")
      create(:location, account: user.account, name: "Long box")
    end

    it "opens a sitting in the chosen place, keeping the page and its camera (AC-1.1, AC-1.2)", :aggregate_failures do
      visit scanner_path
      open_destination
      expect(page).to have_select("Location", selected: "No location")
      expect(list_heading).to eq("This sitting: 0 cards")
      page.execute_script("window.__marker = 'still here'")
      set_sitting(location: "Blue binder")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, in Blue binder")
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: condition not specified, in Blue binder.")
      expect(page).to have_css(".c-scan__dest", text: "Blue binder") # AC-2.3
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      expect(page).to have_css(".c-scan__feed video", visible: :all)
    end

    it "scans into the place, and into another once it changes mid-sitting (AC-1.3, AC-2.1)", :aggregate_failures do
      visit scanner_path
      set_sitting(location: "Blue binder")
      close_sheet
      add_by_scanning
      expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt MOM · 123, foil")
      set_sitting(location: "Long box")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 1 card, in Long box")
      close_sheet
      add_by_scanning
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 2 cards, in Long box")
      expect(entry_metas).to match([ /in Long box/, /in Blue binder/ ])
      expect(user.account.lots.map { [ it.location.name, it.quantity ] }.sort).to eq([ [ "Blue binder", 1 ], [ "Long box", 1 ] ])
    end

    it "keeps the place on a reload, clears it with cards kept, and ends with the control on No location (AC-1.7, AC-1.8, AC-5.2)", :aggregate_failures do
      Scanner::Sitting.choose!(account: user.account, location: user.account.locations.find_by!(name: "Long box"))
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit scanner_path
      open_destination
      expect(page).to have_select("Location", selected: "Long box")
      set_sitting(location: "No location")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, exact_text: "This sitting: 1 card")
      close_sheet
      end_sitting
      expect(page).to have_css("#scanner_added_text", text: "Added 1 card in this sitting.") # AC-5.6
      expect(page).to have_link("Open your collection").and have_css(".c-scan__dest", text: "No location")
      open_destination
      expect(page).to have_select("Location", selected: "No location")
      set_sitting(location: "Blue binder")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, in Blue binder")
    end

    it "chooses a place with the keyboard alone (AC-7.1)", :aggregate_failures do
      visit scanner_path
      open_destination
      field = find_field("Location")
      field.select("Long box")
      field.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
      page.driver.browser.switch_to.active_element.send_keys(:enter)
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, in Long box")
    end

    it "fits a 360px screen with a long location name, never scrolling sideways (AC-7.1)", :aggregate_failures do
      long = create(:location, account: user.account, name: "The second long box under the desk, left of the shelf")
      Scanner::Sitting.choose!(account: user.account, location: long)
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit collection_path
      expect(open_scanner_frame(width: 360, height: 640)).to eq(360)
      within_narrow_frame do
        open_destination
        expect(page_fits_sideways?).to be(true)
        expect(page.evaluate_script("(() => { const t = document.querySelector('.c-scan__dest-text'); return t.scrollWidth > t.clientWidth })()")).to be(true) # AC-1.4
      end
    end
  end

  it "fits a 360px screen with a long sitting, never scrolling sideways (NFR Accessibility)", :aggregate_failures do
    12.times { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: format("%x", it) * 32) }
    visit collection_path
    expect(open_scanner_frame(width: 360, height: 640)).to eq(360)
    within_narrow_frame do
      open_sitting_list
      expect(page_fits_sideways?).to be(true)
      expect_one_screen(640)
    end
  end

  describe "a sitting's condition (spec 042)" do
    def entry_metas
      open_sitting_list
      all("#scanner_sitting li .c-list__meta").map { it.text.squish }
    end

    it "opens a sitting with the condition, keeping the page and its camera (AC-1.2)", :aggregate_failures do
      visit scanner_path
      open_destination
      expect(page).to have_select("Condition", selected: "Not specified")
      expect(page).to have_no_select("Location")
      page.execute_script("window.__marker = 'still here'")
      set_sitting(condition: "Near mint (NM)")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, Near mint")
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: Near mint.")
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      expect(page).to have_css(".c-scan__feed video", visible: :all)
    end

    it "scans into the condition, and into another once it changes mid-sitting (AC-1.3, AC-2.1)", :aggregate_failures do
      visit scanner_path
      set_sitting(condition: "Near mint (NM)")
      close_sheet
      add_by_scanning
      expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt MOM · 123, foil")
      set_sitting(condition: "Lightly played (LP)")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 1 card, Lightly played")
      close_sheet
      add_by_scanning
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 2 cards, Lightly played")
      expect(entry_metas).to match([ /Foil · LP ·/, /Foil · NM ·/ ])
      expect(user.account.lots.map { [ it.condition, it.quantity ] }.sort).to eq([ [ "lightly_played", 1 ], [ "near_mint", 1 ] ])
    end

    it "keeps the condition on a reload, clears it with cards kept, and ends with the control on Not specified (AC-1.7, AC-1.8, AC-5.2)", :aggregate_failures do
      Scanner::Sitting.choose!(account: user.account, condition: "near_mint")
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit scanner_path
      open_destination
      expect(page).to have_select("Condition", selected: "Near mint (NM)")
      set_sitting(condition: "Not specified")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, exact_text: "This sitting: 1 card")
      close_sheet
      click_on "Done"
      click_on "End sitting"
      open_destination
      expect(page).to have_select("Condition", selected: "Not specified")
      set_sitting(condition: "Damaged (DMG)")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, Damaged")
    end

    it "reaches Condition, Location and Set with the keyboard alone (AC-7.1)", :aggregate_failures do
      create(:location, account: user.account, name: "Long box")
      visit scanner_path
      open_destination
      field = find_field("Condition")
      field.select("Near mint (NM)")
      field.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.id")).to eq("sitting_location_id")
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
      page.driver.browser.switch_to.active_element.send_keys(:enter)
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, Near mint")
    end

    it "fits 390px and a desktop width with both selects and a long location name, never scrolling sideways (AC-7.1)", :aggregate_failures do
      long = create(:location, account: user.account, name: "The second long box under the desk, left of the shelf")
      Scanner::Sitting.choose!(account: user.account, condition: "moderately_played", location: long)
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit collection_path
      expect(open_scanner_frame(width: 390, height: 844)).to eq(390)
      within_narrow_frame do
        open_destination
        expect(page_fits_sideways?).to be(true)
        expect(page.evaluate_script(%(Array.from(document.querySelectorAll("#scanner_picker select, #scanner_picker input[type=submit]")).every(el => el.getBoundingClientRect().right <= document.getElementById("scanner_destination_sheet").getBoundingClientRect().right + 1)))).to be(true)
      end
      page.current_window.resize_to(1280, 900)
      visit scanner_path
      open_destination
      expect(page).to have_css("#scanner_picker select#sitting_condition")
      expect(page_fits_sideways?).to be(true)
    end
  end

  describe "focus and the status after a redraw (spec 047)" do
    before { create(:location, account: user.account, name: "Blue binder") }

    def seed(*keys) = keys.each { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: it * 32) }
    def active = page.driver.browser.switch_to.active_element
    # Chooses a condition with the keyboard, then Tabs from Condition through Location to Set (`RSpec/ExampleLength` is 15).
    def choose_condition_and_tab_to_set(label)
      field = find_field("Condition")
      field.select(label)
      field.send_keys(:tab) # Location
      active.send_keys(:tab) # Set
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
    end
    def set_focused = have_css("#scanner_picker input[type=submit][value=Set]:focus")
    # Marks the form's wrapper on the page now; the mark is gone once Turbo has replaced it with the answer's.
    def mark_stale = page.execute_script("document.getElementById('scanner_picker').dataset.stale = '1'")
    def redrawn = have_no_css("#scanner_picker[data-stale]")

    it "puts focus back on Set after a keyboard Set on a sitting with cards, and again on a repeat (AC-1.1, AC-3.1, AC-3.3)", :aggregate_failures do
      seed("a")
      visit scanner_path
      open_destination
      page.execute_script("window.__marker = 'still here'")
      choose_condition_and_tab_to_set("Near mint (NM)")
      active.send_keys(:enter)
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 1 card, Near mint")
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: Near mint, no location.")
      expect(page).to set_focused
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      mark_stale
      active.send_keys(:enter) # Set again, nothing changed: the status says the same, focus is on the new Set
      expect(page).to redrawn
      expect(page).to set_focused
    end

    it "puts focus on Set, with the status, when Set opens a sitting, deletes an empty one, and finds none open (AC-1.2 to AC-1.4)", :aggregate_failures do
      visit scanner_path
      set_sitting(condition: "Near mint (NM)")
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 0 cards, Near mint")
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: Near mint, no location.")
      expect(page).to set_focused
      select "Not specified", from: "Condition"
      click_on "Set"
      expect(page).to have_css("#scanner-sitting-heading", visible: :all, exact_text: "This sitting: 0 cards").and have_no_css(".c-scan__done")
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: condition not specified, no location.")
      expect(page).to set_focused
      mark_stale
      click_on "Set" # no sitting open, both choices empty
      expect(page).to redrawn.and have_css("#scanner_destination_status", text: "Cards you scan now: condition not specified, no location.")
      expect(page).to set_focused
    end

    it "puts focus on the heading after a keyboard Undo; the heading is not a Tab stop (AC-2.1, AC-2.2, AC-2.4)", :aggregate_failures do
      seed("a", "b")
      visit scanner_path
      open_sitting_list
      expect(page.evaluate_script("document.getElementById('scanner-sitting-heading').tabIndex")).to eq(-1)
      find("#scanner_sitting").find_button("Undo", match: :first).send_keys(:enter) # the newest entry's
      expect(page).to have_css("#scanner_list_status", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
      expect(page).to have_css("#scanner-sitting-heading:focus", text: "This sitting: 1 card")
      find("#scanner_sitting").find_button("Undo", match: :first).send_keys(:enter)
      expect(page).to have_css("#scanner_sitting .c-empty", text: "Everything added in this sitting was undone.")
      expect(page).to have_css("#scanner-sitting-heading:focus", text: "This sitting: 0 cards")
      expect(page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")).to eq("solid") # AC-2.4: the focus token's ring
      expect(page.evaluate_script("getComputedStyle(document.activeElement).outlineWidth")).to eq("2px")
    end
  end

  it "shows the add on the after-add line with Undo, the camera live (AC-5.1, AC-5.5, decision 15)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", exact_text: "Added Lightning Bolt MOM · 123, foil")
    expect(page).to have_css(".c-scan__line--added:not([hidden]) .c-scan__added-action button", text: "Undo")
    expect(page).to have_css(".c-scan__line--status[hidden]", visible: :all)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_button("Capture", disabled: false)
    expect(page.evaluate_script("document.activeElement.hasAttribute('data-scan-main')")).to be(true)
    expect(page).to have_css(".c-scan__done", text: "Done")
    page.execute_script("window.__added = document.getElementById('scanner_added_text')")
    add_by_scanning
    expect(page.evaluate_script("window.__added === document.getElementById('scanner_added_text')")).to be(true)
  end

  def count_label = "#scanner_count[aria-label='%s added. Show this sitting\\'s cards.']"
  def counted(number) = have_css(format(count_label, number))

  # A second printing, shown to the camera by its own name and collector line.
  def add_counterspell_by_scanning
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Counterspell"), name: "Counterspell", set: Catalog::Set.find_by!(code: "mom"), number: "124"))
    Catalog::NameIndex.new("mtg").rebuild
    show_synthetic_card(name: "Counterspell", lines: [ "R 0124", "MOM • EN" ])
    click_on "Capture"
    find("button[aria-label='Add Counterspell MOM · 124 Foil']", wait: 30).click
  end

  it "reads the place and the short condition on the top bar after one Set (spec 082 AC-2.3)", :aggregate_failures do
    create(:location, account: user.account, name: "Blue binder")
    visit scanner_path
    open_destination
    select "Near mint (NM)", from: "Condition"
    select "Blue binder", from: "Location"
    click_on "Set"
    expect(page).to have_css(".c-scan__dest-text", exact_text: "Blue binder · NM")
    expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now: Near mint, in Blue binder.")
  end

  it "shows the sitting's choices on the top bar after leaving the scanner and coming back (spec 082 AC-2.5)", :aggregate_failures do
    binder = create(:location, account: user.account, name: "Blue binder")
    visit scanner_path
    expect(page).to have_css(".c-scan__dest-text", exact_text: "No location")
    Scanner::Sitting.choose!(account: user.account, condition: "near_mint", location: binder)
    visit more_path
    visit scanner_path
    expect(page).to have_css(".c-scan__dest-text", exact_text: "Blue binder · NM")
    expect(page).to have_css(".c-scan__done")
  end

  it "hides the frozen frame once an add has cleared the result (spec 082 AC-5.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
    expect(page).to have_css("#scanner_added_text", text: "Added")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_no_css(".c-scan--result")
  end

  it "offers no Undo after an Undo from the after-add line, and the count reads one less (spec 082 AC-5.3)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    add_by_scanning
    expect(page).to counted(2)
    click_on "Undo"
    expect(page).to have_css("#scanner_added_text", text: "Removed 1 × Lightning Bolt")
    expect(page).to have_no_button("Undo")
    expect(page).to counted(1)
    expect(page.evaluate_script("document.querySelector('#scanner_added_action').children.length")).to eq(0)
  end

  it "names the second card on the second Undo when two different cards were added (spec 082 AC-5.5)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt")
    add_counterspell_by_scanning
    expect(page).to have_css("#scanner_added_text", text: "Added Counterspell MOM · 124, foil")
    expect(page).to have_button("Undo Counterspell (MOM · 124, Foil)").and have_no_button("Undo Lightning Bolt (MOM · 123, Foil)")
    click_on "Undo"
    expect(page).to have_css("#scanner_added_text", text: "Removed 1 × Counterspell (MOM · 124, Foil)")
    expect(user.account.lots.map { it.entry.name }).to eq([ "Lightning Bolt" ])
  end

  # The end-of-sitting summary's link and its sentence, measured in one script: the link is outside the live region and on its row.
  def summary_geometry
    page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector("#scanner_added_action a"), text = document.getElementById("scanner_added_text")
        const a = link.getBoundingClientRect(), t = text.getBoundingClientRect()
        return { inStatus: !!link.closest("[role=status]"), besideText: a.left >= t.left && a.top < t.bottom && a.bottom > t.top,
                 sameWrapper: link.closest(".c-scan__line--added") === text.closest(".c-scan__line--added") }
      })()
    JS
  end

  it "puts Open your collection beside the end-of-sitting sentence, outside its live region (spec 082 AC-5.6)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt")
    end_sitting
    expect(page).to have_css("#scanner_added_text", text: "Added 1 card in this sitting.")
    expect(page).to have_link("Open your collection")
    expect(summary_geometry).to eq("inStatus" => false, "besideText" => true, "sameWrapper" => true)
  end

  it "counts one less after an Undo in the list sheet (spec 082 AC-6.2)", :aggregate_failures do
    Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
    Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "b" * 32)
    visit scanner_path
    expect(page).to counted(2)
    open_sitting_list
    find("#scanner_sitting").find_button("Undo", match: :first).click
    expect(page).to have_css("#scanner_list_status", text: "Removed 1 × Lightning Bolt")
    expect(page).to counted(1)
    expect(page).to have_css("#scanner-sitting-heading", visible: :all, text: "This sitting: 1 card")
  end

  it "returns focus to the destination after a Set redrew it while the sheet was open (decision 15, AC-2.4)", :aggregate_failures do
    visit scanner_path
    find(".c-scan__dest").send_keys(:enter)
    select "Near mint (NM)", from: "Condition"
    click_on "Set"
    expect(page).to have_css(".c-scan__dest", text: "No location · NM")
    find("dialog[open]").send_keys(:escape)
    expect(page.evaluate_script("document.activeElement.classList.contains('c-scan__dest')")).to be(true)
  end

  # The page-load alert flash is drawn by the server with this class (`_added_line`); the example puts it on the line as that render
  # does, since no page the scanner can be left for answers with an alert flash in a way a system example can reach cheaply.
  it "drops the alert style from the after-add line on the next capture", :aggregate_failures do
    visit scanner_path
    page.execute_script("document.querySelector('.c-scan__line--added').classList.add('c-scan__line--alert')")
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scan--result .c-scanner__candidate", wait: 30)
    expect(page).to have_no_css(".c-scan__line--alert", visible: :all)
  end

  it "drops the alert style once an Undo from the list sheet writes its answer on the line", :aggregate_failures do
    Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
    visit scanner_path
    page.execute_script("document.querySelector('.c-scan__line--added').classList.add('c-scan__line--alert')")
    open_sitting_list
    find("#scanner_sitting").find_button("Undo", match: :first).click
    expect(page).to have_css("#scanner_added_text", text: "Removed", visible: :all)
    expect(page).to have_no_css(".c-scan__line--alert", visible: :all)
  end

  it "empties the after-add line on the next capture (AC-5.4)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", text: "Added")
    show_synthetic_card
    hold_readings # the reading waits for the request, so the status line can't be replaced by an answer before it is asserted
    click_on "Capture"
    expect(page).to have_css(".c-scan__line--added[hidden]", visible: :all)
    expect(page).to have_css(".c-scan__line--status:not([hidden])")
    eventually("typeof window.__release === 'function'", wait: 30)
    page.execute_script("window.__release()")
    expect(page).to have_button("Scan again", wait: 30)
  end
end
