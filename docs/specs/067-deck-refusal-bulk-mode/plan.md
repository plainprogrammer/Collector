# Plan: Open a Deck's Lots in Bulk Mode from Its Refusal Page (spec 067)

**Spec:** [spec.md](spec.md) 0.2.0 (approved, Gate A, 2026-11-11). **Branch:** `067-deck-refusal-bulk-mode`. **Issue:** [#302](https://github.com/plainprogrammer/Collector/issues/302).

## Goal

Add `POST /decks/:deck_id/selection` and a "Move them in bulk mode" button on the deck refusal page that starts a bulk selection of every lot of the deck under the filter `deck:<id>`. The sequence is written once, in a controller concern both shortcuts use. No schema, export or dependency change.

## Gates checked

- **Simplicity:** three components (one concern, one controller, one route plus one view line).
- **Anti-abstraction:** the concern is justified by spec decision 3 (one definition for both shortcuts); `BulkSelection#restart!(all: true)` is reused unchanged.
- **Integration-first:** the request contract (route, status, redirect, selection state) is written as failing specs in Phase 1 before any code.

## File map

| File | Change | Responsibility |
|---|---|---|
| `app/controllers/concerns/bulk_mode_shortcut.rb` | new | `open_in_bulk_mode(location_filter)`: restart the session's selection under a filter string with every matching lot selected and redirect to the bulk table |
| `app/controllers/locations/selections_controller.rb` | edit | Find the place, call the concern; header comment updated |
| `app/controllers/decks/selections_controller.rb` | new | Find the deck through the account, call the concern with `deck:<location id>` |
| `app/models/bulk_selection.rb` | edit (comment only) | `restart!`'s comment names both shortcuts |
| `config/routes.rb` | edit | `resource :selection, only: :create, module: :decks` under `resources :decks`, with a spec 067 comment |
| `app/views/decks/removals/refused.html.erb` | edit | The button, first in the actions row |
| `spec/requests/deck_bulk_shortcut_spec.rb` | new | Stories 1, 2, 4 (request level) |
| `spec/system/deck_bulk_shortcut_spec.rb` | new | Story 3, AC-5.1 (plain form button, no scripting assumed), AC-5.2 |
| `spec/requests/decks_spec.rb`, `spec/system/decks_spec.rb` | edit | The spec 062 AC-3.3 examples that say "no bulk button" now say the button is there |
| `spec/deck_core_spec.rb` | edit | Count 26 to 27 |
| `spec/import_apply_core_spec.rb` | edit | List gains the concern's file |
| `docs/architecture/collection-and-lots.md`, `tenancy-and-accounts.md`, `docs/design-system/components/DecksIndex.md`, `CLAUDE.md` | edit | As the spec's "Documents that change" table says |

Before editing the view (Task 3), the implementer reads `docs/design-system/README.md` and `docs/design-system/components/Locations.md` and uses the `collector-design-system` skill; the button reuses `c-btn c-btn--primary` and `button_to` exactly as `app/views/locations/removals/refused.html.erb` does, so no CSS is added.

---

## Phase 1: Contracts as failing specs (Task 1)

**Implements:** AC-1.1–AC-1.6, AC-2.1–AC-2.9, AC-4.1–AC-4.6, FR-1, FR-2. **Files:** the two request specs, `spec/requests/decks_spec.rb`.

### Task 1: Failing request specs and the guards that must change first

1. In `spec/requests/decks_spec.rb`, change the AC-3.3 example named "refuses a deck with lots in two zones ... with no Remove and no bulk button" so it says the button is there. Replace its last two expectations and its description:

```ruby
      it "refuses a deck with lots in two zones, counting and listing each lot with its zone, with no Remove and the bulk shortcut first (AC-3.3; spec 067 AC-1.1)", :aggregate_failures do
        # ... setup and the expectations before the buttons ones are unchanged
        expect(html.at_css("a[href='#{decks_path}']", text: "Back to decks")).to be_present
        expect(buttons).to eq([ "Move them in bulk mode from “Izzet Tempo”" ])
        expect(html.css("main form").map { it["action"] }).to eq([ deck_selection_path(deck) ])
      end
```

2. Create `spec/requests/deck_bulk_shortcut_spec.rb`. Mirror `spec/requests/location_bulk_shortcut_spec.rb` with these differences (write every example; each is a copy of the place example with the changes listed):

```ruby
require "rails_helper"

# Spec 067: the deck refusal page's shortcut into bulk mode (#302).
RSpec.describe "Open a deck's lots in bulk mode", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)
  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def shortcut_form = page_html.at_css("main form[action='#{deck_selection_path(deck)}']")
  def deck_value = CollectionFilter::Place.deck_value(deck.location_id) # the name `collection_deck_filter_spec.rb` uses; never a hand-built string
  # untouched_bulk_form(go): as in the place spec, with rendered_location: deck_value
end
```

   - `describe "the button on the refusal page (Story 1)"`: lots in `deck.zone("main")` (5 copies) and `deck.zone("sideboard")` (7 copies) from `own(..., location: deck.zone(...), quantity:)`. Examples AC-1.1 (actions children texts `[ "Move them in bulk mode from “Izzet Tempo”", "Back to decks" ]`, hidden tail `.c-sr` equals ` from “Izzet Tempo”`, classes include `c-btn c-btn--primary`, no control matching `/Remove/`), AC-1.2 (`delete deck_path(deck)` is 409 and `shortcut_form` present), AC-1.3 (an empty second deck's `new_deck_removal_path` has `main form button` texts `[ "Remove" ]`), AC-1.4 (method post, one button, only `authenticity_token` input, no link to the path), AC-1.5 (sentence "“Izzet Tempo” holds 12 copies in 2 lots. Move them before removing it.", 2 `#held_lots li`, zones read "Izzet Tempo › Main"/"Izzet Tempo › Sideboard", "Back to decks" link), AC-1.6 (a place's refusal page still posts to `location_selection_path(box)`: give `box` a lot first, `own("Card Z", location: box)`, or its page is the confirmation page), and "is not on the Decks page" (`get decks_path`, no form to `deck_selection_path`).
   - `describe "pressing it (Story 2)"`: `let!(:held)` of Card A (5, main), Card B (7, sideboard) and Card C (28, in `box`). Examples:
     - AC-2.1/2.2: `post deck_selection_path(deck)`; `expect(response).to have_http_status(:see_other).and redirect_to(collection_path(bulk: 1, location: deck_value))` and `expect(response.location).to include("location=deck%3A#{deck.location_id}")` (the colon is percent-encoded); follow; rows `contain_exactly("Card A", "Card B")`, two `tr[aria-selected=true]`, `.c-bulkbar__count` "All 12 items selected", header checked, `.c-filterbar__count` "12 of 40 items", `select[name=location] option[selected]` text "Izzet Tempo (all zones)", place cells read "Izzet Tempo › Main" and "Izzet Tempo › Sideboard".
     - AC-2.3: bar buttons `[ "Set condition…", "Move to…", "Remove" ]`; `patch collection_selection_path, params: untouched_bulk_form("move")`; follow; `h1` "Move 12 items"; `select#to option` texts equal `[ "Choose…", "No location", "Long box", *deck.zones.map { "Izzet Tempo › #{it.name}" } ]` (a deck filter leaves nothing out).
     - AC-2.4, AC-2.5, AC-2.8 (Done redirects to `collection_path(location: deck_value)`): as the place examples, with `deck_value` in place of `blue.id.to_s`.
     - AC-2.6: `account.lots.where(location: deck.zones).delete_all`; post; follow; main text includes "No cards in your collection are in “Izzet Tempo”."; "0 of 0 selected"; no header checkbox. And the empty-collection case (`account.lots.delete_all`, body includes "No cards in your collection yet.").
     - AC-2.7: post; empty the zones' lots; `deck.remove!`; `get collection_path(bulk: 1, location: deck_value)` is 200, one row (Card C), none selected.
     - AC-2.9 (Move to…, Set condition and Remove all act on exactly the deck's lots): post, then `patch collection_selection_path, params: untouched_bulk_form("move")`, follow, `post collection_move_path, params: { to: box.id }`; the lots of both zones are in `box`, Card C is unchanged. (Use the route names of `spec/requests/bulk_move_spec.rb`.) Add the same shape for Set condition (the submission of `spec/requests/bulk_condition_spec.rb`: the zone lots keep their zones, Card C keeps its condition) and for Remove (the all-matching examples of `spec/requests/bulk_zone_filter_spec.rb` are the pattern; Card C stays).
     - Performance: the statement count of `post` is the same with 30 more lots (`count_queries`, as the place spec).
   - `describe "only my decks (Story 4)"`: `foreign` deck of another account. Examples: AC-4.1 (404, selections unchanged for both accounts), AC-4.2 (a place's id, a zone's id, a missing id: all 404, no selection), AC-4.3 (params `q`, `location`, `sort`, `account_id`, `admin` ignored; selection is `[ "", deck_value, default sort key, account.id ]`), AC-4.4 (signed out redirects to `new_session_path`, nothing created), AC-4.5 (`get "/decks/#{deck.location_id}/selection"` and with `"Sec-Purpose" => "prefetch"` are 404, nothing created), AC-4.6 (`post location_selection_path(deck.location)` and `(deck.zone("main"))` are 404; a place's `post location_selection_path(box)` is a 303 to `collection_path(bulk: 1, location: box.id)`).

3. Run `bin/rspec spec/requests/deck_bulk_shortcut_spec.rb spec/requests/decks_spec.rb`. **Expected:** every example that calls `deck_selection_path` fails with `NameError: undefined local variable or method 'deck_selection_path'`; the changed AC-3.3 example fails because the actions row holds no button; AC-1.3, AC-1.5, AC-1.6 and AC-4.6 pass already (they guard behaviour that exists and must stay), as does the rest of `decks_spec.rb`. Do not push before Task 3: Tasks 1 and 2 leave the suite red or half-moved and the pre-push hook runs the full `bin/ci`.

4. Commit: `test(decks): specify the deck refusal page's shortcut into bulk mode (spec 067)`.

---

## Phase 2: One definition of the shortcut (Task 2)

**Implements:** decision 3, FR-1's "Must not change the place shortcut". **Files:** `bulk_mode_shortcut.rb`, `locations/selections_controller.rb`, `bulk_selection.rb` (comment), `spec/import_apply_core_spec.rb`.

### Task 2: Extract the concern; the place shortcut uses it (a refactor with its guards)

1. **Failing guard first.** In `spec/import_apply_core_spec.rb`, add `app/controllers/concerns/bulk_mode_shortcut.rb` to the end of the `files` list, after `app/controllers/locations/selections_controller.rb`. Run `bin/rspec spec/import_apply_core_spec.rb`: the "exists, every file of it" example fails because the file is missing.

2. Create `app/controllers/concerns/bulk_mode_shortcut.rb`:

```ruby
# What a refusal page's "Move them in bulk mode" button does, once for every kind of place a collector can empty: start the
# session's bulk selection under a location filter with every matching lot selected, and go to the bulk table under it
# (spec 059 decisions 1 and 3 for a place; spec 067 for a deck). It is the sequence spec 041 decision 5 described (filter,
# Edit many, select every matching lot) in one POST. The including controller finds the thing in the path through
# `Current.account` first (a 404 there ends the request before anything is stored) and passes only the filter string, so no
# request parameter is ever read here.
#
# @see file:collection-and-lots.md
module BulkModeShortcut
  extend ActiveSupport::Concern

  private
    # Replaces the session's stored selection, as Edit many does, and answers 303 to the bulk table.
    #
    # @param location_filter [String] the location filter's canonical string, `"<id>"` or `"deck:<id>"` (spec 037 decision 1;
    #   spec 065 decision 4), built by the caller from a record it found through the account
    # @return [void]
    def open_in_bulk_mode(location_filter)
      sort = CollectionTable::Sort.parse(nil, nil)
      BulkSelection.for(Current.session).restart!(query: "", sort:, location: location_filter, all: true)
      redirect_to helpers.collection_listing_path(bulk: 1, location: location_filter, sort:), status: :see_other
    end
end
```

3. Replace `app/controllers/locations/selections_controller.rb` with:

```ruby
# The place refusal page's shortcut into bulk mode (spec 059, #187): a form button because Edit many is never a link
# (spec 006 FR-1). The place in the path is the only parameter read; what pressing does is `BulkModeShortcut`'s, which a
# deck's refusal page shares (`Decks::SelectionsController`, spec 067).
#
# @see file:collection-and-lots.md
class Locations::SelectionsController < ApplicationController
  include BulkModeShortcut

  # 404 for a location that isn't one of the account's places (spec 059 AC-4.1; a deck or a zone is not one, spec 062 AC-3.8).
  def create
    open_in_bulk_mode(Current.account.locations.places.find(params[:location_id]).id.to_s)
  end
end
```

4. In `app/models/bulk_selection.rb`, change the `restart!` comment's phrase "and a location's shortcut from its refusal page (spec 059 decision 3)" to "and the shortcut on a place's or a deck's refusal page (spec 059 decision 3; spec 067, through `BulkModeShortcut`)".

5. Run `bin/rspec spec/import_apply_core_spec.rb spec/requests/location_bulk_shortcut_spec.rb spec/models/bulk_selection_spec.rb`. **Expected: all pass** (the guard now finds the file; the place shortcut behaves as before).

6. Commit: `refactor(locations): share the refusal shortcut's sequence in BulkModeShortcut (spec 067 decision 3)`.

---

## Phase 3: The deck's route, controller and button (Task 3)

**Implements:** AC-1.x, 2.x, 4.x, FR-1, FR-2, FR-3. **Files:** `routes.rb`, `decks/selections_controller.rb`, `decks/removals/refused.html.erb`, `spec/deck_core_spec.rb`, the 062 system example.

### Task 3: Route, controller, view, and the remaining guards

0. **First (it fails against the old view):** `spec/system/decks_spec.rb`, the 360px refusal example: replace `expect(page).to have_no_css("main button", text: /Remove|bulk/)` with `expect(page).to have_css("main button", text: "Move them in bulk mode")` and `expect(page).to have_no_css("main button", text: /\\ARemove/)`; keep `fits?`. Run it and see it fail.

1. In `config/routes.rb`, inside `resources :decks`, after the `format` line:

```ruby
    resource :selection, only: :create, module: :decks # spec 067: the refusal page's shortcut into bulk mode
```

2. Create `app/controllers/decks/selections_controller.rb`:

```ruby
# The deck refusal page's shortcut into bulk mode (spec 067, #302), the place shortcut's sibling
# (`Locations::SelectionsController`, spec 059). The lookup is `Decks::RemovalsController`'s: by the deck's location id
# through the account, so another account's deck, a place and a zone are all 404 (spec 067 AC-4.1, AC-4.2). The selection is
# under the filter that means every zone of the deck (`CollectionFilter::Place.deck_value`, `deck:<id>`, spec 065 decision 4); what pressing does is
# `BulkModeShortcut`'s. The deck in the path is the only parameter read.
#
# @see file:collection-and-lots.md
class Decks::SelectionsController < ApplicationController
  include BulkModeShortcut

  # Starts the selection of every lot of the deck and answers 303 to the bulk table under it.
  def create
    deck = Current.account.decks.find_by!(location_id: params[:deck_id])
    open_in_bulk_mode(CollectionFilter::Place.deck_value(deck.location_id))
  end
end
```

3. In `app/views/decks/removals/refused.html.erb`, replace the actions row with (the first line is new, the second is as it was):

```erb
    <div class="c-form__actions">
      <%= button_to deck_selection_path(@deck), class: "c-btn c-btn--primary" do %>Move them in bulk mode<span class="c-sr"> from “<%= @deck.name %>”</span><% end %>
      <%= link_to "Back to decks", decks_path, class: "c-btn c-btn--secondary" %>
    </div>
```

4. `spec/deck_core_spec.rb`: change `20 + 6` to `20 + 6 + 1` and its comment to add "; spec 067 adds the selections controller (the glob already covers it)".

5. Run `bin/rspec spec/requests/deck_bulk_shortcut_spec.rb spec/requests/decks_spec.rb spec/requests/location_bulk_shortcut_spec.rb spec/deck_core_spec.rb spec/import_apply_core_spec.rb spec/system/decks_spec.rb`. **Expected: all pass.** Then `bin/rubocop -a` on the touched Ruby files.

6. Commit: `feat(decks): open a deck's lots in bulk mode from its removal refusal page (spec 067, #302)`.

---

## Phase 4: The browser (Task 4)

**Implements:** AC-3.1, AC-5.1, AC-5.2, the Accessibility NFR. **Files:** `spec/system/deck_bulk_shortcut_spec.rb`.

### Task 4: System spec: end to end, keyboard, 360px in both themes

Create `spec/system/deck_bulk_shortcut_spec.rb` by copying `spec/system/location_bulk_shortcut_spec.rb` with these changes (the helpers `tab_to_text`, `open_in_narrow_frame`, `within_narrow_frame` are the same):

```ruby
RSpec.describe "Open a deck's lots in bulk mode", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  before { create(:location, account:, name: "Long box") }

  it "empties a deck from its refusal page through Move to… and on to its removal (AC-3.1, AC-2.2, AC-2.3)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: refusal, bulk mode, move, then the removal it unlocks
    create_lot_in_zone(deck, "main", quantity: 2)
    create_lot_in_zone(deck, "sideboard", quantity: 3)
    visit decks_path
    click_on "Remove Izzet Tempo"
    expect(page).to have_css("h1", text: "“Izzet Tempo” isn't empty")

    click_on "Move them in bulk mode"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
    expect(page).to have_css("tbody tr[aria-selected=true]", count: 2)
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", exact_text: "Move 5 items")
    select "Long box", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 5 items to Long box.")
    expect(page).to have_text("No cards in your collection are in “Izzet Tempo”.")
    expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 0 selected") # the selection restarts empty under a deck filter (spec 065 decision 12)
    expect(account.lots.where(location: deck.zones)).to be_empty

    visit decks_path
    click_on "Remove Izzet Tempo"
    expect(page).to have_css("h1", text: "Remove Izzet Tempo?")
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Izzet Tempo”.")
  end
end
```

Add the keyboard example (`visit new_deck_removal_path(deck)`, `tab_to_text("Move them in bulk mode")`, visible focus ring, enter, then "All 4 items selected") and the 360px example (`open_in_narrow_frame(new_deck_removal_path(deck), width: 360, ready: "main")`, both themes, `scrollWidth <= innerWidth`, no `main a, main button` under 44px, the button first in `.c-form__actions`), each as in the place system spec with `deck` and "Izzet Tempo" in place of `blue` and "Blue binder". **Without scripting (AC-5.1, AC-3.1)** gets its own example in a separate top-level `RSpec.describe "Open a deck's lots in bulk mode without scripting", type: :system` in the same file, whose first line is `before { driven_by :rack_test }` declared before the `let!(:user)` that signs in (`system_sign_in_as` is a plain form, so it works under `rack_test`): create two lots in the deck's zones, `visit new_deck_removal_path(deck)`, `click_on "Move them in bulk mode"`, expect `.c-bulkbar__count` "All 5 items selected" and two `tr[aria-selected=true]`, then `click_on "Move to…"` within `.c-bulkbar__extra` and expect the `h1` "Move 5 items". If `driven_by :rack_test` can't take effect after `spec/support/system.rb`'s hook, stop and ask the coordinator (the fallback is a spec update to AC-3.1, "with scripting; no script by the request spec").

Run `bin/rspec spec/system/deck_bulk_shortcut_spec.rb`. **Expected: pass** (the production code exists since Task 3; this task adds the proof, and a failing run here means a gap in Task 3). Commit: `test(decks): prove the deck shortcut in a browser, with the keyboard and at 360px (spec 067)`.

---

## Phase 5: Documents (Task 5)

**Implements:** the spec's "Documents that change" table. **Files:** the area docs, the design-system doc, `CLAUDE.md`. The comments that changed (`restart!`, both controllers) were updated in Tasks 2 and 3.

### Task 5: Update the documents in this pull request

- `docs/architecture/collection-and-lots.md`: the decks table's "holding lots in any zone / Remove" row (the actions row's first control is "Move them in bulk mode", a POST button to `/decks/:id/selection`: spec 067 AC-1.1, AC-1.4); the Decisions line "A deck is removed only while empty" (the shortcut exists, spec 067); the #50 bullet's last sentence in Accepted limits (remove the #302 sentence); the Glossary's *Bulk mode* and the bulk mode section's opening (a deck's refusal page starts it too, under `deck:<id>`, through `BulkModeShortcut`); the prefetch invariant (add "and the deck refusal page's"); the core guard sentence (27 deck files, name `Decks::SelectionsController` and `BulkModeShortcut` in `import_apply_core_spec.rb`'s list); the Sources entry for spec 065 and an entry for spec 067; one Distillation-log row is left to the `distill-feature` step. Each new statement cites its spec criterion inline.
- `docs/architecture/tenancy-and-accounts.md`: the deck-lookup invariant gains `Decks::SelectionsController` and `POST /decks/:id/selection`.
- `docs/design-system/components/DecksIndex.md`: the refusal bullet's "Back to decks as the only action" (and line 115's "no 'Move them in bulk mode' button ... #302") become "the primary button 'Move them in bulk mode' first (its hidden tail names the deck), then 'Back to decks'".
- `CLAUDE.md`: the status paragraph's decks sentence gains "and opens its lots in bulk mode from its removal refusal page (spec 067)" after the format sentence; the "Collection and lots" non-obvious fact's spec list gains 067.
- `docs/design-system/components/DecksIndex.md` also has the refusal's markup block (only "Back to decks" in `.c-form__actions`, near line 126): show the `button_to` form with its `c-sr` tail first. `docs/architecture/collection-and-lots.md`'s list of open issues (near line 308) names #302: move it with spec 067 to the closed ones.
- Check with `git grep -n "#302\|no shortcut\|no bulk-mode\|stays places-only" -- docs CLAUDE.md ':!.kamal/secrets'` that no document still says the deck page has no shortcut (frozen specs 059, 062 and 065 are not edited).

Commit: `docs(architecture): the deck refusal page's bulk-mode shortcut (spec 067)`.

---

## Phase 6: Verification (Task 6)

### Task 6: Full verification, `verification.md`, and the implementation review

- `bin/rubocop`, `bin/rspec` on the touched files, then `bin/ci` once (the coordinator's slot) and `bin/yard doc` (the new comments build without a warning; the ratchet checks the concern).
- Write `verification.md` with one line of evidence per criterion (request file, system file, reading for the documents and the contrast checks of AC-5.2), then the `## Implementation review` section after the Opus read-only Mode B review.

## Self-review

- **Spec coverage:** FR-1 (Tasks 2, 3), FR-2 (Task 3), FR-3 (Tasks 2, 3: counts and list), decisions 1–5 (Tasks 2–3), Story 3 and 5 (Task 4), supersessions and documents (Task 5, plus the index written with the spec).
- **Placeholders:** none; the two spec files are written by copying named examples with the listed substitutions, every substitution stated.
- **Types:** `open_in_bulk_mode(location_filter)` is defined in Task 2 and called in Tasks 2 and 3 with a String; routes `deck_selection_path(deck)` is the helper Rails gives `resource :selection` nested in `resources :decks` (`deck_selection`), as `location_selection_path` is for locations.
