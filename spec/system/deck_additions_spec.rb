require "rails_helper"

# Spec 071 Story 5 (AC-5.5) and Story 6 (AC-6.1 to AC-6.5): the Add to deck page in a browser, with and without scripting.
RSpec.describe "Add to deck", type: :system do
  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}") # no colour is read here, so no pause (testing.md: no sleep)

  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  # The drawn height of every control of the page, by kind. `html` is pinned to a scrollbar in both pointer states, so a
  # taller page can't narrow the layout by a scrollbar's width and move what wraps (spec 072's lesson).
  def control_heights
    page.execute_script("document.documentElement.style.overflowY = 'scroll'")
    page.evaluate_script(<<~JS)
      (() => { const height = (el) => el.getBoundingClientRect().height
        return { select: height(document.querySelector("#deck_zone")),
                 input: height(document.querySelector("label.c-input")),
                 rows: [...document.querySelectorAll(".c-pick .c-check")].map(height),
                 buttons: [...document.querySelectorAll(".c-form__actions .c-btn")].map(height) } })()
    JS
  end

  context "with scripting" do
    let!(:user) { system_sign_in_as(create(:user)) }
    let(:account) { user.account }
    let(:wide_entry) { create(:mtg_printing, entry: create(:catalog_entry, name: "W" * 60), finishes: %w[nonfoil foil]).entry }

    before do
      create(:deck, account:, name: "D" * 60)
      create(:lot, account:, entry: wide_entry, quantity: 2, location: create(:location, account:, name: "P" * 60))
      create(:lot, account:, entry: wide_entry, quantity: 1)
    end

    %w[light dark].each do |theme|
      [ 360, 640, 1280 ].each do |width|
        it "fits at #{width}px in the #{theme} theme with 60-character deck, place and card names (AC-6.1)", :aggregate_failures do
          visit catalog_entry_path(wide_entry) # the outer page hosts the frame
          open_in_narrow_frame(new_catalog_entry_deck_addition_path(wide_entry), width:, ready: "main")
          within_narrow_frame do
            set_theme(theme)
            expect(fits?).to be(true)
            overflow = page.evaluate_script(<<~JS)
              (() => { const form = document.querySelector(".c-form").getBoundingClientRect()
                const select = document.querySelector("#deck_zone").getBoundingClientRect()
                const text = document.createRange(); text.selectNodeContents(document.querySelector(".c-pick .c-check"))
                return { select: select.width <= form.width, text: text.getBoundingClientRect().right <= document.querySelector(".c-pick").getBoundingClientRect().right + 0.5,
                         title: document.querySelector(".c-pagehead__title").getBoundingClientRect().right <= window.innerWidth } })()
            JS
            expect(overflow).to eq("select" => true, "text" => true, "title" => true)
          end
        end
      end
    end

    it "shows the 2px focus ring on the radio row that has keyboard focus (AC-6.2)", :aggregate_failures do
      visit new_catalog_entry_deck_addition_path(wide_entry)
      find("#deck_zone").send_keys(:tab, :tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("copies")
      ring = page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement.closest('label')); return [ s.outlineStyle, s.outlineWidth ] })()")
      expect(ring).to eq([ "solid", "2px" ])
    end

    # Headless Firefox has a fine pointer, so the coarse rules are applied by `apply_coarse_rules` (all of them, as a device
    # draws them) and the controls are measured as drawn. The radio rows' rule is this spec's own and must be in the
    # stylesheets, or the example fails by naming it.
    describe "the 44px floor (AC-6.3, AC-6.4)" do
      before { visit new_catalog_entry_deck_addition_path(wide_entry) }

      it "draws every control of the page at 44px or more once the coarse rules apply", :aggregate_failures do
        apply_coarse_rules(needs: [ ".c-decks .c-pick .c-check", ".c-field select, .c-select select", ".c-btn, .c-input" ])
        heights = control_heights

        expect(heights["rows"].size).to eq(3) # My copies and a proxy of each finish
        expect(heights["buttons"].size).to eq(2) # Add to deck and Cancel
        expect([ heights["select"], heights["input"], *heights["rows"], *heights["buttons"] ]).to all(be >= 44)
      end

      # The first row's text wraps (a 60-character place name), so it is tall already; the two proxy rows are one line.
      it "draws the one-line radio rows, the select and the number field under 44px with a fine pointer, so the rules are what lift them", :aggregate_failures do
        heights = control_heights

        expect(heights["rows"].last(2)).to all(be < 44)
        expect(heights["select"]).to be < 44
        expect(heights["input"]).to be < 44
      end

      it "names the rule that is missing when the stylesheets lack it" do
        expect { apply_coarse_rules(needs: [ ".c-decks .c-no-such-rule" ]) }.to raise_error(/\.c-no-such-rule.*not in the loaded stylesheets/)
      end
    end

    it "keeps the new rule under its own heading, scoped to the pick list, with no colour or font literal (AC-6.4)", :aggregate_failures do
      css = Rails.root.join("app/assets/stylesheets/collector/additions.css").read
      block = css[/\/\* -+ Add to deck's radio rows \(spec 071\).*?(?=\n\/\* -{5,}|\z)/m]
      expect(block).to be_present
      expect(block).to include("@media (pointer: coarse) { .c-decks .c-pick .c-check { min-height:var(--touch-floor); } }")
      expect(block).not_to match(/#[0-9a-fA-F]{3,6}\b|font-family|rgb\(/)
    end
  end

  # AC-5.5: the whole path in a browser that runs no script, a system example per use. `driven_by :rack_test` comes before the
  # `let!` that signs in, or the sign-in would go through Firefox; the sign-in is a plain form.
  context "without scripting" do
    before { driven_by :rack_test }

    let!(:user) { system_sign_in_as(create(:user)) }
    let(:account) { user.account }
    let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
    let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

    it "moves free copies from the card page to the deck page (AC-5.5)", :aggregate_failures do
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      create(:lot, account:, entry:, quantity: 2, location: create(:location, account:, name: "Blue binder"))
      visit catalog_entry_path(entry)
      click_link "Add to deck"
      select "Izzet Tempo › Main", from: "Deck and zone"
      fill_in "How many", with: "2"
      choose "My copies (2 free: 2 in Blue binder)"
      click_button "Add to deck"

      expect(page).to have_current_path(catalog_entry_path(entry))
      expect(page).to have_content("Moved 2 copies of Lightning Bolt to Izzet Tempo › Main.")
      expect(page).to have_css("#copies", text: "Izzet Tempo › Main")
      visit deck_path(deck)
      expect(page).to have_css("section.c-zone", text: "Lightning Bolt")
    end

    it "records a proxy from the card page and shows it on the deck page (AC-5.5)", :aggregate_failures do
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      visit catalog_entry_path(entry)
      click_link "Add to deck"
      select "Izzet Tempo › Sideboard", from: "Deck and zone"
      fill_in "How many", with: "3"
      choose "A proxy of #{ApplicationController.helpers.set_number(entry)} Foil"
      click_button "Add to deck"

      expect(page).to have_content("Added 3 proxies of Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}, Foil) to Izzet Tempo › Sideboard.")
      visit deck_path(deck)
      expect(page).to have_css(".c-proxy", text: /Proxy\s+3/)
    end
  end
end
