# Implementation Plan: Open a Location's Lots in Bulk Mode from Its Refusal Page

**Spec:** docs/specs/059-bulk-mode-from-location-refusal/spec.md (0.2.0, approved)
**Decisions:** none new (no ADR: the spec's decisions 1–6 are the whole design)
**Created:** 2026-11-10

## Global Constraints

- The button's label is "Move them in bulk mode", sentence case, with a visually hidden tail ` from “<location name>”` (`c-sr`) as the list's Rename and Remove buttons have; it is a `c-btn c-btn--primary`, first in the page's `c-form__actions`, followed by "Back to locations" (spec decision 2).
- The shortcut is a `<button>` in a `form method="post"`, never a link, with no field but the CSRF token (spec 006 FR-1; AC-1.4).
- One route, `POST /locations/:location_id/selection` → `Locations::SelectionsController#create`; no other verb. The location is found only through `Current.account.locations`; the only parameter read is the location id in the path (FR-1; AC-4.3).
- The selection is `BulkSelection#restart!` under name filter `""`, the location's id as its canonical filter string, the default sort, with every matching lot selected, in `restart!`'s one transaction; the answer is 303 to `/collection?bulk=1&location=<id>` (decisions 1, 3).
- Design system only: tokens and `c-*` classes, no new CSS expected (`.c-locations .c-btn` already gives the 44px floor); no collectible's name in the controller, the view or their comments; the controller joins the fixed file list of `spec/import_apply_core_spec.rb` (FR-3).
- No data, schema, export or import change (decision 6); every comment that describes changed behaviour changes in the same commit (`.claude/rules/code-documentation.md`); YARD builds without warnings.
- Specs 006, 032 and 041 are not edited (`.claude/rules/documentation.md`); the index records the supersessions, already written with the spec.

---

## Goal

A collector on a location's removal refusal page presses "Move them in bulk mode" and lands on the bulk table filtered to that location with every lot in it selected, so "Move to…" is one press away.

---

## Phase 0: Tests First, and the "Before" Screenshots

**Implements:** FR-1, FR-2, FR-3, Stories 1–5 | **Satisfies:** AC-1.1–AC-1.5, AC-2.1–AC-2.7, AC-2.6a, AC-3.1, AC-4.1–AC-4.5, AC-5.1, AC-5.2
**Files:** `spec/models/bulk_selection_spec.rb` (modified), `spec/requests/location_bulk_shortcut_spec.rb` (new), `spec/system/location_bulk_shortcut_spec.rb` (new), `spec/system/locations_spec.rb` (modified), `spec/support/keyboard_helpers.rb` (new, `tab_to` moved from the locations system spec), `docs/specs/059-bulk-mode-from-location-refusal/screenshots/` (new, "before" shots)
**Interfaces:** Consumes: nothing. Produces: the failing examples of every later phase, using these names that Phase 1 and 2 must provide: `BulkSelection#restart!(query:, sort:, location: "", all: false)`, `location_selection_path(location)` (route helper, `POST`), `Locations::SelectionsController#create`.

The tests that every later phase turns green, written before any implementation. The one existing example that contradicts the new page (spec 032 AC-5.2's "no button in main" at 360px) is changed to what the page now holds. A few new examples pass before the implementation (the default `restart!`, the GETs of AC-4.5 that 404 for want of a route, AC-1.3); they are regression guards, not broken tests.

- [ ] Take the "before" screenshots first, while the page is still as it was: the refusal page of "Blue binder" holding 3 lots, light and dark, at 1280px and at 360px (a fixed-width iframe, `.claude/memory`'s PR screenshots workflow and "Headless Firefox narrow frame" memories; headless Firefox prefers dark, so set `data-theme` for the light shots too, and pause 0.6s after a theme switch). Save as `docs/specs/059-bulk-mode-from-location-refusal/screenshots/before-refusal-{desktop,phone}-{light,dark}.jpg` with `magick`. Seed with one runner script in its own shell call. Commit: `docs(spec): 059 before screenshots of the refusal page (#187)`.
- [ ] Add the model examples to `spec/models/bulk_selection_spec.rb`, inside `RSpec.describe BulkSelection`, after the example "starts empty under the default filter and sort":

```ruby
  describe "#restart! with all: true (spec 059 decision 3)" do
    let!(:blue) { create(:location, account:, name: "Blue binder") }

    it "selects every matching lot of the location in the restart's own write, with no exceptions", :aggregate_failures do
      held = own("Card A", location: blue, quantity: 2)
      also = own("Card B", location: blue, quantity: 3)
      elsewhere = own("Card C")
      selection.restart!(query: "", sort: default_sort, location: blue.id.to_s, all: true)

      expect(selection.lots).to contain_exactly(held, also)
      expect(selection.lots).not_to include(elsewhere)
      expect([ selection.everything?, selection.copies, selection.location_filter ]).to eq([ true, 5, blue.id.to_s ])
    end

    it "replaces earlier ticks and marks", :aggregate_failures do
      first = own("Card A", location: blue)
      second = own("Card B", location: blue)
      tick([ first, second ], [ first ])
      selection.restart!(query: "", sort: default_sort, location: blue.id.to_s, all: true)

      expect(selection.marks).to be_empty
      expect(selection.lots).to contain_exactly(first, second)
    end

    it "leaves the default restart selecting nothing (Edit many)", :aggregate_failures do
      own("Card A", location: blue)
      selection.restart!(query: "", sort: default_sort, location: blue.id.to_s)

      expect(selection.lots).to be_empty
      expect(selection.everything?).to be(false)
    end
  end
```

- [ ] Create `spec/requests/location_bulk_shortcut_spec.rb`:

```ruby
require "rails_helper"

# Spec 059: the refusal page's shortcut into bulk mode (#187).
RSpec.describe "Open a location's lots in bulk mode", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def shortcut_form = page_html.at_css("main form[action='#{location_selection_path(blue)}']")

  describe "the button on the refusal page (Story 1)" do
    before do
      own("Card A", location: blue, quantity: 5)
      own("Card B", location: blue, quantity: 7)
    end

    it "is first in the actions row, before Back to locations, with no Remove button (AC-1.1)", :aggregate_failures do
      get new_location_removal_path(blue)

      actions = page_html.at_css("main .c-form__actions")
      expect(actions.element_children.map { |child| child.text.squish }).to eq([ "Move them in bulk mode from “Blue binder”", "Back to locations" ])
      expect(page_html.at_css("main .c-form__actions button").text.squish).to eq("Move them in bulk mode from “Blue binder”")
      expect(page_html.at_css("main .c-form__actions button .c-sr").text).to eq(" from “Blue binder”")
      expect(page_html.at_css("main .c-form__actions button")["class"].split).to include("c-btn", "c-btn--primary")
      expect(page_html.css("main button, main input[type=submit]").map { |control| control.text + control["value"].to_s }.grep(/Remove/)).to be_empty
    end

    it "is on the refusal page a refused DELETE renders (AC-1.2)", :aggregate_failures do
      delete location_path(blue)

      expect(response).to have_http_status(:conflict)
      expect(shortcut_form).to be_present
    end

    it "is not on an empty location's confirmation page (AC-1.3)" do
      get new_location_removal_path(box)

      expect(page_html.css("main form button").map(&:text).map(&:squish)).to eq([ "Remove" ])
    end

    it "is a post form with a button and no field but the token (AC-1.4)", :aggregate_failures do
      get new_location_removal_path(blue)

      expect(shortcut_form["method"]).to eq("post")
      expect(shortcut_form.css("button").size).to eq(1)
      expect(shortcut_form.css("input").map { |field| field["name"] }.uniq - [ "authenticity_token" ]).to be_empty
      expect(page_html.css("main a").map { |link| link["href"] }).not_to include(location_selection_path(blue))
    end

    it "keeps the sentence, the list and Back to locations as they were (AC-1.5)", :aggregate_failures do
      get new_location_removal_path(blue)

      expect(page_html.at_css("main").text.squish).to include("“Blue binder” holds 12 copies in 2 lots. Move them before removing it.")
      expect(page_html.css("#held_lots li").size).to eq(2)
      expect(page_html.css("main a").map(&:text)).to include("Back to locations")
    end

    it "is not on the locations list (decision 5)" do
      get locations_path

      expect(page_html.css("form[action='#{location_selection_path(blue)}']")).to be_empty
    end
  end

  describe "pressing it (Story 2)" do
    # Two lots of 5 and 7 copies in Blue binder, then one of 28 in Long box (one helper: RSpec/MultipleMemoizedHelpers allows 5).
    let!(:held) { [ own("Card A", location: blue, quantity: 5), own("Card B", location: blue, quantity: 7), own("Card C", location: box, quantity: 28) ] }

    it "answers 303 to the bulk table under the location, with every lot selected (AC-2.1, AC-2.2)", :aggregate_failures do
      post location_selection_path(blue)

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path(bulk: 1, location: blue.id))
      follow_redirect!
      expect(page_html.css("tbody tr").map { |row| row.at_css("a").text }).to contain_exactly("Card A", "Card B")
      expect(page_html.css("tbody tr[aria-selected=true]").size).to eq(2)
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("All 12 items selected")
      expect(page_html.at_css("thead input[name=all]")["checked"]).to be_present
      expect(page_html.at_css(".c-filterbar__count").text.squish).to eq("12 of 40 items")
      expect(page_html.at_css("select[name=location] option[selected]").text).to eq("Blue binder")
    end

    it "offers the bulk actions and opens Move to… for every copy, without the location as a destination (AC-2.3)", :aggregate_failures do
      post location_selection_path(blue)
      get collection_path(bulk: 1, location: blue.id)
      expect(page_html.css(".c-bulkbar__extra button").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])

      ids = held.first(2).map(&:id)
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: blue.id.to_s, all_rendered: "1", all: "1",
        shown_ids: ids, baseline_ids: ids, ticked_ids: ids }
      follow_redirect!
      expect(page_html.at_css("h1").text).to eq("Move 12 items")
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Long box" ])
    end

    it "replaces the stored selection, its ticks included (AC-2.4)", :aggregate_failures do
      post collection_selection_path, params: { q: "card", location: box.id, sort: "price", dir: "desc" }
      patch collection_selection_path, params: { go: "filter", q: "card", location: box.id, rendered_q: "card", rendered_location: box.id.to_s,
        sort: "price", dir: "desc", all_rendered: "0", shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      selection = BulkSelection.find_by!(account:)
      expect(selection.marks.count).to eq(1)

      post location_selection_path(blue)

      selection.reload
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.all_matching, selection.marks.count ]).to eq([ "", blue.id.to_s, CollectionTable::Sort.parse(nil, nil).key, true, 0 ])
      expect(BulkSelection.where(account:).count).to eq(1)
    end

    it "leaves an undoable bulk removal undoable (AC-2.5)", :aggregate_failures do
      post collection_selection_path
      patch collection_selection_path, params: { go: "remove", rendered_q: "", rendered_location: "", all_rendered: "0",
        shown_ids: [ held.last.id ], ticked_ids: [ held.last.id ] }
      post collection_bulk_removals_path
      undoable = BulkRemoval.where(account:).undoable.last
      expect(undoable).to be_present

      post location_selection_path(blue)

      expect(undoable.reload).to be_undoable
    end

    it "lands on the empty-filter table when the location was emptied meanwhile (AC-2.6)", :aggregate_failures do
      account.lots.where(location: blue).delete_all
      post location_selection_path(blue)

      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      follow_redirect!
      expect(page_html.at_css("main").text.squish).to include("No cards in your collection are in “Blue binder”.")
      expect(page_html.at_css(".c-bulkbar__count").text.squish).to eq("0 of 0 selected")
      expect(page_html.css("thead input[type=checkbox]")).to be_empty
    end

    it "lands on the empty collection's page when no lot is left at all (AC-2.6)", :aggregate_failures do
      account.lots.delete_all
      post location_selection_path(blue)
      follow_redirect!

      expect(response.body).to include("No cards in your collection yet.")
      expect(page_html.css(".c-bulkbar")).to be_empty
    end

    it "costs a number of statements independent of the lots it selects (Performance NFR)" do
      post location_selection_path(blue) # the selection exists and holds these values, so both measured calls do the same writes
      few = count_queries { post location_selection_path(blue) }
      30.times { |n| own("Extra #{n}", location: blue) }

      expect(count_queries { post location_selection_path(blue) }).to eq(few)
    end

    it "reads a location removed after the redirect as all locations, nothing selected (AC-2.6a)", :aggregate_failures do
      post location_selection_path(blue)
      account.lots.where(location: blue).delete_all
      blue.destroy!
      get collection_path(bulk: 1, location: blue.id)

      expect(response).to have_http_status(:ok)
      expect(page_html.css("tbody tr").size).to eq(1)
      expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
    end

    it "returns to the saved view under the location on Done (AC-2.7)", :aggregate_failures do
      post location_selection_path(blue)
      patch collection_selection_path, params: { go: "done", rendered_q: "", rendered_location: blue.id.to_s }

      expect(response).to redirect_to(collection_path(location: blue.id))
      expect(BulkSelection.where(account:)).to be_empty
    end
  end

  describe "only my locations (Story 4)" do
    let!(:foreign) { create(:location, account: create(:user).account, name: "Their binder") }

    it "answers 404 for another account's location and changes nothing (AC-4.1)", :aggregate_failures do
      post collection_selection_path
      stored = BulkSelection.where(account:).map(&:attributes)

      post location_selection_path(foreign)

      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:).map(&:attributes)).to eq(stored)
      expect(BulkSelection.where(account: foreign.account)).to be_empty
    end

    it "answers 404 for a location that doesn't exist (AC-4.2)" do
      post location_selection_path(blue.id + 1000)

      expect(response).to have_http_status(:not_found)
    end

    it "ignores a name filter, location, sort, account or user value in the request (AC-4.3)", :aggregate_failures do
      own("Card A", location: blue)
      post location_selection_path(blue), params: { q: "zzz", location: box.id, sort: "price", dir: "desc", account_id: foreign.account.id, user_id: 1, admin: "1" }

      expect(response).to redirect_to(collection_path(bulk: 1, location: blue.id))
      selection = BulkSelection.find_by!(account:)
      expect([ selection.query, selection.location_filter, selection.sort_key, selection.account_id ]).to eq([ "", blue.id.to_s, CollectionTable::Sort.parse(nil, nil).key, account.id ])
    end

    it "sends a signed-out visitor to sign-in and creates nothing (AC-4.4)", :aggregate_failures do
      delete session_path
      post location_selection_path(blue)

      expect(response).to redirect_to(new_session_path)
      expect(BulkSelection.where(account:)).to be_empty
    end

    it "answers no GET, prefetch-marked or not, and changes nothing (AC-4.5)", :aggregate_failures do
      get "/locations/#{blue.id}/selection"
      expect(response).to have_http_status(:not_found)

      get "/locations/#{blue.id}/selection", headers: { "Sec-Purpose" => "prefetch" }
      expect(response).to have_http_status(:not_found)
      expect(BulkSelection.where(account:)).to be_empty
    end
  end
end
```
- [ ] Create `spec/system/location_bulk_shortcut_spec.rb`:

```ruby
require "rails_helper"

# Spec 059: the shortcut in a browser, end to end, at 360px, both themes, and with the keyboard.
RSpec.describe "Open a location's lots in bulk mode", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }

  before { create(:location, account:, name: "Long box") } # the destination; reached by its name

  it "empties a location from its refusal page through Move to… (AC-3.1, AC-2.2, AC-2.3)", :aggregate_failures do
    owned_printing("Card A", account:, location: blue, quantity: 2)
    owned_printing("Card B", account:, location: blue, quantity: 3)
    visit locations_path
    click_on "Remove Blue binder"
    expect(page).to have_css("h1", text: "“Blue binder” isn't empty")

    click_on "Move them in bulk mode"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
    expect(page).to have_css("tbody tr[aria-selected=true]", count: 2)
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", exact_text: "Move 5 items")
    select "Long box", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 5 items to Long box.")
    expect(account.lots.where(location: blue)).to be_empty
  end

  it "lets the emptied location be removed from its confirmation page (AC-3.1)", :aggregate_failures do
    visit locations_path
    click_on "Remove Blue binder"
    expect(page).to have_css("h1", text: "Remove Blue binder?")
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Blue binder”.")
  end

  it "works with the keyboard alone: tab to the button and press enter (Accessibility NFR)", :aggregate_failures do
    owned_printing(account:, location: blue, quantity: 4)
    visit new_location_removal_path(blue)

    expect(tab_to("Move them in bulk mode")).to be(true)
    ring = page.evaluate_script("(() => { const el = document.activeElement; const style = getComputedStyle(el); return el.matches(':focus-visible') && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0 })()")
    expect(ring).to be(true) # a visible focus ring (Accessibility NFR)
    page.driver.browser.action.send_keys(:enter).perform
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 4 items selected")
  end

  it "fits at 360px in both themes with 44px targets and the button first (AC-5.2)", :aggregate_failures do
    owned_printing(account:, location: blue, quantity: 3)

    %w[light dark].each do |theme|
      expect(open_in_narrow_frame(new_location_removal_path(blue), width: 360, ready: "main")).to eq([ 360, true ])
      within_narrow_frame do
        page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), theme
        small = page.evaluate_script("[...document.querySelectorAll('main a, main button')].filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).map((el) => el.outerHTML.slice(0, 60))")
        expect(small).to eq([]), theme
        expect(page.evaluate_script("document.querySelector('main .c-form__actions').firstElementChild.textContent.trim()")).to start_with("Move them in bulk mode")
      end
    end
  end
end
```

- [ ] Update the existing example in `spec/system/locations_spec.rb` (spec 032 AC-5.2: "offers no Remove, and its links keep the 44px floor"). Its line `expect(page.evaluate_script("[...document.querySelectorAll('main button, main input[type=submit]')].length")).to eq(0)` becomes the button this spec adds, and only it. Replace that one line with:

```ruby
      expect(page.evaluate_script("[...document.querySelectorAll('main button, main input[type=submit]')].map((el) => el.textContent.trim())")).to eq([ "Move them in bulk mode from “Blue binder”" ]) # spec 059: the shortcut, and no Remove (spec 032 AC-5.2)
```

  Change the comment above it (`# Spec 032 AC-5.2: the refusal page fits at 360px, offers no Remove, and its links keep the 44px floor.`) to `# Spec 032 AC-5.2: the refusal page fits at 360px, offers no Remove (only spec 059's shortcut), and its targets keep the 44px floor.` and change the example's title to `"refuses a location that holds lots without scrolling sideways, with 44px targets and the keyboard (spec 032 AC-5.2; spec 059 AC-5.2)"`, and `#targets` there already includes `main button`, so the 44px count line stays.
- [ ] Move `tab_to(text)` out of `spec/system/locations_spec.rb` (its last method) into `spec/support/keyboard_helpers.rb`, so the new system spec reuses it instead of duplicating it (`.claude/rules/code-documentation.md`, finding code before writing it). Delete the method and its comment from `locations_spec.rb`; create the file:

```ruby
# Keyboard navigation for system specs (spec 029 AC-5.5; spec 059).
module KeyboardHelpers
  # Tabs until a focused control (never the page's body, whose text includes everything) has text that includes the given
  # text, at most 40 times; false if none does.
  def tab_to(text)
    40.times do
      return true if page.evaluate_script("document.activeElement !== document.body && document.activeElement.textContent.includes(arguments[0])", text)

      page.driver.browser.action.send_keys(:tab).perform
    end
    false
  end
end

RSpec.configure do |config|
  config.include KeyboardHelpers, type: :system
end
```

  The old method returned true before pressing Tab whenever the page's text held the words (the body's does), so `tab_to("Back to locations")` in `locations_spec.rb` never tested the keyboard; with the body excluded it now does. `spec/system/bulk_move_spec.rb` has its own `tab_to(id)`, defined in its example group, which takes precedence over the module's; leave it.
- [ ] Run `script/worktree/with_mise bin/rspec spec/models/bulk_selection_spec.rb spec/requests/location_bulk_shortcut_spec.rb spec/system/location_bulk_shortcut_spec.rb spec/system/locations_spec.rb` — expect FAIL (the `all:` keyword, the route and the button don't exist; the `locations_spec.rb` example fails on the missing button).
- [ ] Commit: `test: failing examples for the refusal page's bulk shortcut (#187)` (the tests only, the screenshots in their own commit above).

---

## Phase 1: The Selection, the Route and the Controller

**Implements:** FR-1, FR-3 | **Satisfies:** AC-2.1, AC-2.2, AC-2.4–AC-2.7, AC-4.1–AC-4.5 (the answer; the button is Phase 2)
**Files:** `app/models/bulk_selection.rb`, `app/controllers/locations/selections_controller.rb` (new), `config/routes.rb`, `spec/import_apply_core_spec.rb`
**Interfaces:** Consumes: `BulkSelection.for(session)`, `CollectionTable::Sort.parse(nil, nil)`, `helpers.collection_listing_path(bulk:, location:, query:, sort:)`. Produces: `BulkSelection#restart!(query:, sort:, location: "", all: false)`; `POST /locations/:location_id/selection`, route helper `location_selection_path`.

The selection can start already holding every matching lot, and one POST route does it for one location of the account.

- [ ] Add `app/controllers/locations/selections_controller.rb` to the `files` list of `spec/import_apply_core_spec.rb` (after `app/views/locations/removals/refused.html.erb`). Run `script/worktree/with_mise bin/rspec spec/import_apply_core_spec.rb` — expect FAIL ("exists, every file of it": the file isn't there yet). It is the guard's own failing test (FR-3).
- [ ] Implement `restart!`: in `app/models/bulk_selection.rb` replace the comment and method

```ruby
  # Empty again, under a filter, location and sort: Edit many, a changed filter or sort, a removal (FR-4, AC-7.3; spec 037
  # decision 5). The marks are this selection's own rows, so deleting them in SQL skips nothing.
  def restart!(query:, sort:, location: "")
    transaction do
      marks.delete_all
      update!(query:, sort_key: sort.key, location_filter: location, all_matching: false)
    end
  end
```

  with

```ruby
  # Starts again under a filter, location and sort: Edit many, a changed filter or sort, a removal (FR-4, AC-7.3; spec 037
  # decision 5), and a location's shortcut from its refusal page (spec 059 decision 3). Nothing is selected unless `all:`;
  # then every matching lot is, with no exceptions, set in the same transaction so a failure can't leave the filter stored
  # with nothing ticked. The marks are this selection's own rows, so deleting them in SQL skips nothing.
  #
  # @param query [String] the name filter, already normalised
  # @param sort [CollectionTable::Sort] the table's order
  # @param location [String] the location filter's canonical string (`""`, `"none"` or an id)
  # @param all [Boolean] select every matching lot (the header's state) instead of none
  # @return [true] the result of the update
  def restart!(query:, sort:, location: "", all: false)
    transaction do
      marks.delete_all
      update!(query:, sort_key: sort.key, location_filter: location, all_matching: all)
    end
  end
```

- [ ] Add the route, in `config/routes.rb`, inside `resources :locations … do`:

```ruby
  resources :locations, only: %i[index create edit update destroy] do
    resource :removal, only: :new, module: :locations
    resource :selection, only: :create, module: :locations # spec 059: the refusal page's shortcut into bulk mode
  end
```

- [ ] Create `app/controllers/locations/selections_controller.rb`:

```ruby
# The refusal page's shortcut into bulk mode (spec 059, #187): starts the session's bulk selection under one of the
# account's locations with every matching lot selected, and goes to the bulk table. It is the sequence spec 041 decision 5
# described (filter, Edit many, select every matching lot) in one POST, a form button because Edit many is never a link
# (spec 006 FR-1). The location in the path is the only parameter read.
#
# @see file:collection-and-lots.md
class Locations::SelectionsController < ApplicationController
  # 404 for a location that isn't the account's (spec 059 AC-4.1). Replaces any stored selection, as Edit many does.
  def create
    location = Current.account.locations.find(params[:location_id])
    sort = CollectionTable::Sort.parse(nil, nil)
    BulkSelection.for(Current.session).restart!(query: "", sort:, location: location.id.to_s, all: true)
    redirect_to helpers.collection_listing_path(bulk: 1, location: location.id.to_s, sort:), status: :see_other
  end
end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/models/bulk_selection_spec.rb spec/requests/location_bulk_shortcut_spec.rb spec/import_apply_core_spec.rb spec/requests/bulk_mode_spec.rb spec/models/bulk_removal_spec.rb` — expect: the model examples, the "pressing it" and "only my locations" request examples and the core spec PASS; the "button on the refusal page" examples still FAIL (Phase 2); bulk mode and removal specs stay green (the default `all:` is unchanged).
- [ ] Commit: `feat: POST /locations/:id/selection opens bulk mode on a location with every lot selected (#187)`

---

## Phase 2: The Button

**Implements:** FR-2 | **Satisfies:** AC-1.1–AC-1.5, AC-3.1, AC-5.1, AC-5.2
**Files:** `app/views/locations/removals/refused.html.erb`, `docs/design-system/components/Locations.md`
**Interfaces:** Consumes: `location_selection_path(@location)` (Phase 1). Produces: the primary button, first in the refusal page's `.c-form__actions`.

The refusal page offers the shortcut; it is the page's one primary action and the first control of its actions row.

- [ ] In `app/views/locations/removals/refused.html.erb` replace

```erb
    <div class="c-form__actions">
      <%= link_to "Back to locations", locations_path, class: "c-btn c-btn--secondary" %>
    </div>
```

  with

```erb
    <div class="c-form__actions">
      <%= button_to location_selection_path(@location), class: "c-btn c-btn--primary" do %>Move them in bulk mode<span class="c-sr"> from “<%= @location.name %>”</span><% end %>
      <%= link_to "Back to locations", locations_path, class: "c-btn c-btn--secondary" %>
    </div>
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/requests/location_bulk_shortcut_spec.rb spec/requests/locations_spec.rb spec/system/location_bulk_shortcut_spec.rb spec/system/locations_spec.rb spec/system/bulk_move_spec.rb` — expect PASS. If the phone example reports a target under 44px or a sideways scroll, fix it in `app/assets/stylesheets/collector/additions.css` with tokens only and record the rule in `Locations.md` in the same commit; none is expected, because `.c-locations .c-btn` has the floor and `.c-form__actions` wraps.
- [ ] Update `docs/design-system/components/Locations.md`: in the refusal page bullet ("What a location holds (spec 032)"), after "…and one "Back to locations" `c-btn--secondary`." change the end of the sentence to read: the actions row is the `c-btn--primary` "Move them in bulk mode" first (a `button_to` form posting to `/locations/:id/selection`, with a `c-sr` tail ` from “Blue binder”` naming the location, spec 059) and then "Back to locations" `c-btn--secondary`; and in its markup note that the button is never a link (spec 006 FR-1). Keep "no `c-btn--danger` button".
- [ ] Commit: `feat: "Move them in bulk mode" on a location's refusal page (#187)`

---

## Phase 3: Documents and Evidence

**Implements:** Documents that change (spec) | **Satisfies:** the spec's Documents-that-change table
**Files:** `docs/architecture/collection-and-lots.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/specs/059-bulk-mode-from-location-refusal/verification.md`, `docs/specs/059-bulk-mode-from-location-refusal/screenshots/`
**Interfaces:** Consumes: Phases 1–2. Produces: area doc truth, the "after" screenshots, `verification.md`.

The documents say what the code now does, and the PR carries the before/after screenshots. Documents are verified by reading, not by RSpec (`.claude/rules/testing.md`).

- [ ] `docs/architecture/collection-and-lots.md`: (a) the locations table's "holding lots / Remove" row: add after "…no Remove button." the first control, "Move them in bulk mode" (a POST button, spec 059 AC-1.1, AC-1.4); (b) replace the sentence "A location is emptied by filtering the collection to it, `Edit many`, selecting every matching lot and choosing "Move to…"; a shortcut from the refusal page is [#187](…) (spec 041 decision 5)." with the same sentence ending "…; the refusal page's "Move them in bulk mode" does the first three steps at once (`POST /locations/:id/selection`, `Locations::SelectionsController`, spec 059; #187)."; (c) Glossary *Bulk mode*: "entered with `Edit many` (or from a location's refusal page, spec 059) and left with `Done`"; (d) Bulk mode section: after the first sentence add "A location's refusal page starts it the same way with every matching lot of that location selected under no name filter and the default sort (`BulkSelection#restart!`'s `all:`; spec 059 decisions 1, 3, 4)."; (e) the prefetch invariant: add "the refusal page's shortcut is a POST button" to the list of buttons-never-links (spec 059 AC-1.4, AC-4.5); (f) Scope: add `Locations::SelectionsController` to the bulk mode and locations lines; (g) Accepted limits: delete "[#187](…): no shortcut from a location's refusal page into bulk mode." and the "open: … #187" in the Sources issue list becomes closed with spec 059; (h) Sources: add `[Spec 059](../specs/059-bulk-mode-from-location-refusal/spec.md): all (the refusal page's shortcut)`, its supersessions (spec 041 decision 5, spec 006 FR-4 and Story 4's entry, spec 032 AC-5.2 and AC-5.4), and #187; (i) the Distillation log row is the distillation step's (`distill-feature`), not this task's.
- [ ] `CLAUDE.md` Project Status: after "…and moves every copy of many lots at once from bulk mode with Move to… (`Lot::BulkMove`, spec 041)" add ", and opens a location's lots in bulk mode from its removal refusal page with one button (`Locations::SelectionsController`, spec 059)". `docs/roadmap.md` item 14c: mark it as done by spec 059 the way neighbouring done items are marked (read the file's convention first). `docs/specs/README.md`: row 059 Status "Approved" (the distillation step changes it to Frozen).
- [ ] Take the "after" screenshots with the same runner and names as the "before" ones: `after-refusal-{desktop,phone}-{light,dark}.jpg` of the refusal page, plus `after-bulk-table-{desktop,phone}-{light,dark}.jpg` of the page the button opens ("All 12 items selected"). Commit: `docs(spec): 059 after screenshots (#187)`.
- [ ] Write `docs/specs/059-bulk-mode-from-location-refusal/verification.md`: one row per AC with the example that proves it (file and example name), the measured results of the 360px/44px/theme example, the screenshots table (before and after, light and dark, desktop and phone), the keyboard check (the system example), the decisions' rulings, and the `## Implementation review` heading left for `sdd-review`.
- [ ] Commit: `docs: 059 area doc, design-system doc, status and verification (#187)`

---

## Phase 4: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `script/worktree/with_mise bin/rubocop` — expect no offenses; `script/worktree/with_mise bin/yard doc` — expect no warnings (the new comments use `@see file:collection-and-lots.md`, no braces); `script/worktree/with_mise bin/rails zeitwerk:check` — expect "All is good!".
- [ ] `script/worktree/with_mise bin/rspec spec/models spec/requests spec/system/locations_spec.rb spec/system/location_bulk_shortcut_spec.rb spec/system/bulk_mode_spec.rb spec/system/bulk_move_spec.rb spec/system/narrow_bulk_pages_spec.rb spec/import_apply_core_spec.rb` — expect PASS.
- [ ] Ask the coordinator for the CI slot, then `bin/ci` (full) once; record the SHA, the example count and the result in `verification.md`; send "slot released" afterwards. The pre-push hook runs the same.
- [ ] Verify each acceptance criterion against `verification.md`; run `sdd-superpowers:sdd-review` Mode B (read-only, Opus) and record it under `## Implementation review`.
- [ ] Commit: `docs: 059 verification record (#187)`

---

## Quickstart Validation

`bin/dev` (or the worktree's port), sign in, add two locations and a few lots in the first. Locations → "Remove" on the first: the refusal page shows "Move them in bulk mode" before "Back to locations". Press it: the URL is `/collection?bulk=1&location=<id>`, the bar reads "All N items selected". Press "Move to…", choose the second location, "Move": the notice reads "Moved N items to <name>." Back on Locations, "Remove" on the first now asks "Remove <name>?" and removes it.
