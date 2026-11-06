# Plan 047: Keep Focus and Announce After the Scanner Sitting Panel Redraws

**Spec:** [spec.md](spec.md) 0.3.0 (Approved, decision 1 ruled: option A). **Issue:** #182. **Branch:** `182-sitting-focus-after-redraw`.

## Goal

After "Set" or "Undo" redraws `#scanner_sitting`, keyboard focus lands on the "Set" button (Set) or the panel heading (Undo); every redraw writes a non-empty sentence in `#status`; nothing else moves focus. The server names the target in a `data-sitting-focus-to-value` on the redrawn panel; a small Stimulus controller focuses it once and removes the attribute.

No migration, no new route, no ADR. Files:

| File | Change |
|---|---|
| `spec/requests/scanner/sittings_spec.rb` | flip the old "status cleared" examples; add focus-target and non-empty-status examples (T1) |
| `app/controllers/concerns/scanner_sitting.rb` | `sitting_stream(message, alert: false, focus: nil)`; no nil-message branch (T2) |
| `app/controllers/scanner/sittings_controller.rb` | `chosen_message` never nil; `focus: :set` on every answer (T2) |
| `app/controllers/scanner/sittings/entries/undos_controller.rb` | `focus: :heading` on both answers (T2) |
| `app/helpers/scanners_helper.rb` | `sitting_focus_data(focus)` (T2) |
| `app/views/scanners/_sitting.html.erb` | `focus` local; both `<section>`s carry the data; heading gets `tabindex="-1"` and a target (T2, T4) |
| `app/views/scanners/_picker.html.erb` | the "Set" submit gets a target (T4) |
| `spec/system/scanner_sitting_spec.rb` | system examples for focus and status (T3) |
| `app/javascript/controllers/sitting_focus_controller.js` | new, ~15 lines (T4) |
| `app/assets/stylesheets/collector/additions.css` | the heading's `:focus-visible` rule (T5) |
| `docs/design-system/components/Scanner.md` | the Set, Undo and heading lines (T5) |
| `docs/specs/047-…/verification.md` | AC table, screenshots, owed screen-reader check, implementation review (T6) |

Gates: **Simplicity** (one controller, one helper, one partial local), **Anti-Abstraction** (no wrapper beyond the helper that builds the attribute hash), **Integration-First** (request examples fix the server's contract before the script exists).

## Phase 1: the server names the focus target and never empties the status

**Implements:** FR-1, FR-2, FR-4 (heading `tabindex`), decision 1, decision 2, decision 3's server half. **Satisfies:** AC-1.5, AC-2.3, AC-3.1, AC-3.2, AC-4.1, AC-4.2; the request half of AC-1.1 to AC-1.4, AC-2.1, AC-2.2. **Files:** the first seven rows above.

### T1: Request examples first (red)

In `spec/requests/scanner/sittings_spec.rb`:

1. **Flip the examples that assert the old clearing** (AC-4.2). Find them with `git grep -n -E "status_cleared\?|not_to include\(\"This sitting:\", \"Cards you scan now\"\)" -- spec ':!.kamal/secrets'`; they are in this file, around lines 233, 474, 523-538 and 541-546 (line numbers drift; use the grep). Delete the `status_cleared?` helper (line 474) and change each use:

```ruby
# 523-538, "deletes a sitting with no card, condition or place …" (rename the example: "and says what the next scan gets (AC-1.8, AC-4.2)")
      expect(status_line).to eq("Cards you scan now: condition not specified.")   # this describe's account has no locations

# 541-546, "clears the status line when both choices are cleared with no sitting open (decision 3)"
    it "says what the next scan gets when both choices are cleared with no sitting open (AC-4.2)", :aggregate_failures do
      blue
      set(condition: "", location_id: "")
      expect(Scanner::Sitting.count).to eq(0)
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
    end
```

The example at the line-233 block (spec 040's "No location" on an empty sitting, an account with locations) keeps `not_to include("This sitting:")` and drops `"Cards you scan now"` from that list; add, after it, `expect(html.at_css("turbo-stream[target=status] .c-status__message").text.squish).to eq("Cards you scan now: condition not specified, no location.")` (written inline: `status_line` is defined only inside the `setting the choices (spec 042)` describe, so it is not in scope in this describe at line 140). The comment "Passes before the change" above the example at line 540 goes with the rewrite (it stops being true). Before editing each, read the example: the account in the `setting the choices (spec 042)` describe has no locations unless `blue` is called; the status sentence follows `account_locations.any?`. For the 523-538 example `blue` is not called, so the sentence has no location part (as written above).

2. **Add a describe `"after a redraw (spec 047)"`** at the end of the file, before the last `end`. `status_line` and `set` are defined inside the `setting the choices` describe, so the new describe defines its own copies:

```ruby
  describe "after a redraw (spec 047)" do
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def set(**fields) = patch(scanner_sitting_path, params: { sitting: fields }, headers: stream)
    def status_line = html.at_css("turbo-stream[target=status] .c-status__message").text.squish
    # Where the redrawn panel says focus goes: nil when it names none.
    def focus_to = html.at_css("#scanner_sitting")["data-sitting-focus-to-value"]

    it "names the Set button after a Set that opens, changes, or clears a sitting (AC-1.1 to AC-1.4)", :aggregate_failures do
      blue
      set(condition: "near_mint")
      expect(focus_to).to eq("set")
      expect(html.at_css("#scanner_sitting")["data-controller"]).to eq("sitting-focus")
      expect(status_line).to eq("Cards you scan now: Near mint, no location.")
      set(condition: "")
      expect(Scanner::Sitting.count).to eq(0)
      expect(focus_to).to eq("set")
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
      set(condition: "", location_id: "")
      expect(focus_to).to eq("set")
      expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
    end

    it "names the Set button after a Set the server refuses, and keeps the alert (AC-1.5)", :aggregate_failures do
      set(condition: "mint-ish")
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("set")
      expect(html.at_css("turbo-stream[target=status] .c-status__message--alert").text.squish).to eq(Scanner::SittingsController::UNKNOWN_CONDITION)
    end

    it "names the Set button when the location is no longer the account's (AC-1.5)", :aggregate_failures do
      set(location_id: create(:location).id) # another account's location
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("set")
      expect(html.at_css("turbo-stream[target=status] .c-status__message--alert").text.squish).to eq(Scanner::SittingsController::GONE)
    end

    it "names the heading after an Undo, done or refused (AC-2.1, AC-2.3)", :aggregate_failures do
      entry = add("a")
      add("b")
      undo(entry)
      expect(focus_to).to eq("heading")
      expect(html.at_css("#scanner_sitting h2[tabindex='-1'][data-sitting-focus-target='heading']").text).to eq("This sitting: 1 card")
      expect(status_line).to start_with("Removed 1 × Lightning Bolt")
      undo(entry)
      expect(response).to have_http_status(:unprocessable_content)
      expect(focus_to).to eq("heading")
      expect(status_line).to eq("That card was already undone.")
    end

    it "names no target after an add, or on the page's own render (AC-3.1, AC-3.2)", :aggregate_failures do
      add("a")
      get scanner_path
      expect(html.at_css("#scanner_sitting")["data-sitting-focus-to-value"]).to be_nil
      expect(html.at_css("#scanner_sitting")["data-controller"]).to be_nil
      post scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: "foil", reading_key: "b" * 32 } }, headers: stream
      expect(response).to have_http_status(:ok)
      expect(focus_to).to be_nil
    end

    it "writes a sentence in #status after every redraw, one example each (AC-4.1)", :aggregate_failures do
      entry = add("a")
      undo(entry)
      expect(status_line).not_to be_blank
      post scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: "foil", reading_key: "a" * 32 } }, headers: stream
      expect(status_line).to eq("You added this card, then undid it. Scan it again to add it.") # a replayed add redraws the panel
      set(condition: "near_mint")
      expect(status_line).not_to be_blank
    end
  end
```

Run `bin/rspec spec/requests/scanner/sittings_spec.rb`: the flipped examples and the new ones fail (red). Commit: `test(scanner): request examples for focus targets and a status after every redraw (spec 047)`.

Before writing, the implementer reads `post scanner_sitting_entries_path` in the file's existing add examples (`git grep -n "scanner_sitting_entries_path" -- spec ':!.kamal/secrets'`) and copies the exact param shape; if the route helper or the param keys differ from the above, the existing examples win.

### T2: The server (green)

`app/controllers/concerns/scanner_sitting.rb`, replace `sitting_stream` and its comment:

```ruby
    # Redraws the panel (after an add, an Undo or a change of place, spec 040 FR-1) and says what happened; the message is
    # never empty, so every redraw is announced (spec 047 FR-1). `focus` is where the new panel puts keyboard focus once it
    # connects: :set after a "Set", :heading after an Undo, nil after an add (spec 047 decision 2).
    def sitting_stream(message, alert: false, focus: nil)
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: sitting_locals.merge(focus:)),
        turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: }) ]
    end
```

`app/controllers/scanner/sittings_controller.rb`:

```ruby
    render turbo_stream: sitting_stream(chosen_message(Scanner::Sitting.choose!(account: Current.account, **choices)), focus: :set)
  ...
    def refuse(message) = render(turbo_stream: sitting_stream(message, alert: true, focus: :set), status: :unprocessable_content)

    # Says what later adds get (spec 042 decision 3, spec 047 decision 1): both choices for an account with locations, the
    # condition alone otherwise. A sitting "Set" deleted, or none open, says the nothing-set sentence: a deleted sitting held
    # neither choice, and `choose!` returns nil when there was none to clear.
    def chosen_message(sitting)
      sitting = nil unless sitting&.persisted? # a destroyed sitting still holds what it had in memory
      parts = [ (sitting&.condition && scanner_conditions.dig(sitting.condition, 0)) || "condition not specified" ]
      parts << (sitting&.location ? "in #{sitting.location.name}" : "no location") if account_locations.any?
      "Cards you scan now: #{parts.join(", ")}."
    end
```

The sentence "nil, which clears the status line" in `chosen_message`'s comment goes with the rewrite above (the class comment has no such sentence). `app/controllers/scanner/sittings/entries/undos_controller.rb`: both `sitting_stream(...)` calls gain `focus: :heading`. `entries_controller.rb` is unchanged (`focus` defaults to nil); its comment "`sitting_stream(message_for(...))`" needs nothing.

`app/helpers/scanners_helper.rb`, add:

```ruby
  # The data of a redrawn sitting panel that puts keyboard focus back (spec 047 decision 3): nil on a page render and after an
  # add, so nothing is focused by them. `focus` is :set or :heading, a word of ours; the Stimulus controller reads it once.
  def sitting_focus_data(focus) = (focus ? { controller: "sitting-focus", sitting_focus_to_value: focus } : nil)
```

`app/views/scanners/_sitting.html.erb`: change the magic comment to `<%# locals: (sitting:, entries:, conditions:, locations:, added_any:, focus: nil) %>`, replace each of the two `<section …>` / `</section>` pairs with `tag.section` blocks, and give the heading `tabindex="-1"`:

```erb
<% if sitting %>
  <% choices = sitting_choices(sitting, conditions) %>
  <%= tag.section id: "scanner_sitting", class: "c-scanner__sitting", aria: { labelledby: "scanner-sitting-heading" }, data: sitting_focus_data(focus) do %>
    <div class="c-section__head">
      <h2 class="c-section__title" id="scanner-sitting-heading" tabindex="-1">This sitting: …unchanged…</h2>
      …unchanged…
  <% end %>
<% else %>
  <%= tag.section id: "scanner_sitting", class: "c-scanner__sitting", data: sitting_focus_data(focus) do %>
    <%= render "scanners/picker", condition: nil, location_id: nil, conditions:, locations: %>
  <% end %>
<% end %>
```

(`tag.section … data: nil` writes no data attribute; a hash writes `data-controller` and `data-sitting-focus-to-value`.) The `data-sitting-focus-target="heading"` attribute on the `h2` is added with the controller in T4; the `h2[data-sitting-focus-target='heading']` expectation of T1's Undo example therefore stays red until T4, so in T1 write that selector as `h2[tabindex='-1']` and add the target to the expectation in T4.

`_picker.html.erb`'s header comment says the control "needs no script (AC-7.1)": reword it to "works without script; a small controller only puts focus back (AC-7.1, spec 047)" in the same commit. This task changes views, so the implementer loads the `collector-design-system` skill first (the copy and markup follow `Scanner.md`; no class or token is added in this task). Run `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/helpers/scanners_helper_spec.rb spec/scanner_sitting_core_spec.rb spec/system/scanner_sitting_spec.rb` (check with `git ls-files spec | grep -i -E "scanner|sitting"` that nothing else names the sitting; a missing file is dropped from the list), then `bin/rubocop -a` on the changed Ruby. Commit `feat(scanner): name the focus target of a redrawn sitting panel and never empty the status (spec 047)`.

## Phase 2: focus moves

**Implements:** FR-3, decision 3's script half. **Satisfies:** AC-1.1 to AC-1.4, AC-2.1, AC-2.2, AC-3.1 (page-level), AC-3.3, AC-2.4's Tab-stop half. **Files:** `spec/system/scanner_sitting_spec.rb`, the controller, `_picker`, `_sitting`.

### T3: System examples first (red)

In `spec/system/scanner_sitting_spec.rb`, add a describe at the end (inside the file's top `RSpec.describe`). It seeds entries with `Scanner::Sitting.add!` before `visit`, as the file's reload examples do, so no example waits on the camera or the OCR engine. It creates a location so the sentences carry the place part. `:focus` is a CSS pseudo-class that Capybara's waiting `have_css` evaluates in the browser (`spec/system/number_entry_spec.rb:15` does the same), so no sleeping is needed. An assertion about the redraw that can pass on the *old* panel (a status sentence or a focused "Set" that was already there) first marks the old panel stale by script and waits for the mark to disappear, which only a replaced panel does:

```ruby
  describe "focus and the status after a redraw (spec 047)" do
    before { create(:location, account: user.account, name: "Blue binder") }

    def seed(*keys) = keys.each { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: it * 32) }
    def active = page.driver.browser.switch_to.active_element
    def set_focused = have_css("#scanner_sitting input[type=submit][value=Set]:focus")
    # Marks the panel on the page now; the mark is gone once Turbo has replaced the panel with the answer's.
    def mark_stale = page.execute_script("document.getElementById('scanner_sitting').dataset.stale = '1'")
    def redrawn = have_no_css("#scanner_sitting[data-stale]")

    it "puts focus back on Set after a keyboard Set on a sitting with cards, and again on a repeat (AC-1.1, AC-3.1, AC-3.3)", :aggregate_failures do
      seed("a")
      visit scanner_path
      expect(page.evaluate_script("document.activeElement.tagName")).to eq("BODY") # the page load focuses nothing
      page.execute_script("window.__marker = 'still here'")
      field = find_field("Condition")
      field.select("Near mint (NM)")
      field.send_keys(:tab) # Location
      active.send_keys(:tab) # Set
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
      active.send_keys(:enter)
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 1 card, Near mint")
      expect(page).to have_css("#status", text: "Cards you scan now: Near mint, no location.")
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
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Near mint")
      expect(page).to have_css("#status", text: "Cards you scan now: Near mint, no location.")
      expect(page).to set_focused
      select "Not specified", from: "Condition"
      click_on "Set"
      expect(page).to have_no_css("#scanner_sitting h2")
      expect(page).to have_css("#status", text: "Cards you scan now: condition not specified, no location.")
      expect(page).to set_focused
      mark_stale
      click_on "Set" # no sitting open, both choices empty
      expect(page).to redrawn
      expect(page).to have_css("#status", text: "Cards you scan now: condition not specified, no location.")
      expect(page).to set_focused
    end

    it "puts focus on the heading after a keyboard Undo; the heading is not a Tab stop (AC-2.1, AC-2.2, AC-2.4)", :aggregate_failures do
      seed("a", "b")
      visit scanner_path
      expect(page.evaluate_script("document.getElementById('scanner-sitting-heading').tabIndex")).to eq(-1)
      find_button("Undo", match: :first).send_keys(:enter) # the newest entry's
      expect(page).to have_css("#status", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
      expect(page).to have_css("#scanner_sitting h2:focus", text: "This sitting: 1 card")
      find_button("Undo", match: :first).send_keys(:enter)
      expect(page).to have_css("#scanner_sitting .c-empty", text: "Everything added in this sitting was undone.")
      expect(page).to have_css("#scanner_sitting h2:focus", text: "This sitting: 0 cards")
    end
  end
```

Notes for the implementer: the Undo control is a `button_to` button named "Undo Lightning Bolt (MOM · 123, Foil)" by `aria-label`; `find_button("Undo", match: :first)` finds it by its text and takes the first, the newest entry's (the list is newest first). If a Capybara version refuses the partial match, use `first("form.c-scanner__undo button")`. The ring (the heading's computed outline) is asserted in T5, not here.

Run `bin/rspec spec/system/scanner_sitting_spec.rb -e "spec 047"`: the three examples fail (red; focus stays on the body). Commit `test(scanner): system examples for focus and the status after a redraw (spec 047)`.

### T4: The Stimulus controller (green)

`app/javascript/controllers/sitting_focus_controller.js` (picked up by `eagerLoadControllersFrom`; no importmap change; no inline script, so the scanner's CSP is unchanged):

```js
import { Controller } from "@hotwired/stimulus"

// Puts keyboard focus back after a Set or an Undo redraws the sitting panel (spec 047). The server names where focus goes
// ("set" or "heading") on the redrawn panel; it is focused once, and the value is removed so a reconnect can't focus again.
// A page render and an add name nothing. The panel works without this: only the focus is lost.
export default class extends Controller {
  static targets = [ "heading", "set" ]
  static values = { to: String }

  connect() {
    const target = this.toValue === "heading" ? this.headingTargets[0] : this.toValue === "set" ? this.setTargets[0] : null
    if (target) target.focus()
    this.element.removeAttribute("data-sitting-focus-to-value")
  }
}
```

Add `data-sitting-focus-target="heading"` to the `h2` in `_sitting.html.erb`, and in `_picker.html.erb` change the submit to `form.submit "Set", class: "c-btn c-btn--secondary c-btn--sm", data: { sitting_focus_target: "set" }`. Update T1's Undo expectation to `h2[tabindex='-1'][data-sitting-focus-target='heading']`. The picker is also rendered by `_summary` (outside the controller's scope): the extra attribute is inert there.

Run the new system examples (green), the whole `spec/system/scanner_sitting_spec.rb` and `spec/requests/scanner`. Commit `feat(scanner): move focus to Set or the heading after the sitting panel redraws (spec 047)`.

## Phase 3: the ring, the docs, the evidence

**Implements:** decision 4, the Supersedes paragraph's doc step. **Satisfies:** AC-2.4, spec FR-5. **Files:** `additions.css`, `Scanner.md`, `verification.md`.

### T5: The heading's focus ring and the Scanner doc

First the failing example: in T3's Undo example (`puts focus on the heading after a keyboard Undo`), after the last `h2:focus` expectation add `expect(page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")).to eq("solid")` and `expect(page.evaluate_script("getComputedStyle(document.activeElement).outlineWidth")).to eq("2px")` (red: the browser's default ring is not `2px solid` on a heading, and the `focus` token is not applied). If headless Firefox does not match `:focus-visible` for a script `focus()` after a keyboard Enter, so the assertion cannot pass honestly, stop and report to the supervisor rather than weaken it: the ring is then proven by the screenshots only and the supervisor amends AC-2.4. Then read `docs/design-system/README.md` and `docs/design-system/components/Scanner.md` (the design-system skill's rule). In `app/assets/stylesheets/collector/additions.css`, directly after the `.c-scanner__sitting .c-section__title` rule (line 189), add, in the pattern of the file's other focus rules:

```css
.c-scanner__sitting .c-section__title:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); } /* the heading takes focus after an Undo (spec 047) */
```

In `docs/design-system/components/Scanner.md`:

- the sitting-control bullet (line 31): replace "The line is cleared when "Set" deletes an empty sitting, or clears both choices with none open (spec 042 decision 3)." with "When "Set" deletes an empty sitting, or clears both choices with none open, the same sentence says "condition not specified" and "no location" (spec 047 decision 1, superseding spec 042 decision 3's cleared line)."; replace "It needs no script: "Set" submits it, and a Turbo Stream redraws the panel" with "It works without script: "Set" submits it, a Turbo Stream redraws the panel and says "Cards you scan now: …" in `#status`, and `sitting_focus_controller.js` then puts focus back on "Set" (spec 047)" (the stream says it; the controller only moves focus);
- the Undo bullet (line 33): add "…and the panel's heading (`h2[tabindex=-1]`, which has a `:focus-visible` ring in `focus`, not a Tab stop) takes focus, since the Undo button is gone (spec 047)";
- add one bullet: "Focus after a redraw (spec 047): the redrawn panel carries `data-controller="sitting-focus"` and `data-sitting-focus-to-value` (`set` after a "Set", `heading` after an Undo) only in the answer to those; the page's own render and an add name nothing, so nothing moves focus."

Verify the outline assertions added at the top of this task now pass (`bin/rspec spec/system/scanner_sitting_spec.rb -e "spec 047"`). Commit `feat(scanner): a focus ring on the sitting heading, and the Scanner doc (spec 047)`.

### T6: Evidence (supervisor, not an implementer)

- **Screenshots** by the project's workflow (memories `pr-screenshots-workflow`, `headless-firefox-narrow-frame`): the sitting heading focused after a keyboard Undo, light and dark, at 1280 px and at 390 px (fixed-width frame); the Set button focused after Set at 1280 px light and dark. Committed under `docs/specs/047-sitting-focus-after-redraw/screenshots/`, linked from `verification.md` and the PR body.
- `verification.md`: an AC table (each AC to its request or system example, AC-2.4's ring to the screenshots), "owed to the maintainer: a screen-reader pass (NVDA or VoiceOver) of Set, Undo and the clearing case, listening for whether the heading and the status together read once or twice", then `## Implementation review` (Mode B, Opus) with the verdict on its first line.
- Then, in the finish order of the brief: `sdd-superpowers:session-wrap`, `distill-feature`, a "ci slot" ask, `bin/ci`, the push slot, the draft PR.

## Spec coverage

| Requirement | Where |
|---|---|
| FR-1 (a sentence for every redraw), AC-4.2, decision 1 | T1, T2 (`chosen_message`, `sitting_stream`) |
| AC-4.1, case by case | add: `spec/requests/scanner/sitting_entries_spec.rb` (existing add examples assert its sentence) and T1's "no target after an add"; replayed add, Undo, Set accepted: T1's "every redraw" example; Undo refused: T1's Undo example; Set refused (condition, location): T1's two refusal examples; Set deleting an empty sitting and Set with none open: T1's first example and the flipped 042 examples |
| FR-2 (the target by answer), AC-1.5, AC-2.3, AC-3.1, AC-3.2 | T1, T2 |
| FR-3 (once, only a named target), AC-1.1 to AC-1.4, AC-2.1, AC-2.2, AC-3.3 | T3, T4 |
| FR-4 (heading `tabindex="-1"`, not a Tab stop), AC-2.4 | T2, T3 (`tabIndex`), T5 (ring) |
| FR-5 (no component, no inline script, one rule) | T4, T5 |
| Supersedes: the Scanner design-system doc | T5 |
| NFR accessibility (owed screen-reader check) | T6 |

## Open items for the plan review

- **P1.** `tag.section … data: nil` should write no data attribute and `data: { controller:, sitting_focus_to_value: }` should write `data-controller` and `data-sitting-focus-to-value`; T1's request examples are the proof, and a reviewer should check Rails 8.1's `tag_options`.
- **P2.** Whether headless Firefox matches `:focus-visible` for a script `focus()` after a keyboard Enter (T5's outline assertion). The fallback is stated in T5.
- **P4 (from plan review round 1, minor 9).** If the collector is in the old panel's Condition or Location select when an answer lands, Turbo's `withPreservedFocus` refocuses the new select by its id one frame after `connect()`, which can override the Set focus (spec Error Scenarios row 2). Not designed around; `verification.md` records it as a known edge.
- **P3.** The stream order: `replace` before `update("status")`. The system examples wait on `#status` text and then on `:focus`, so either order passes; no sleep.
