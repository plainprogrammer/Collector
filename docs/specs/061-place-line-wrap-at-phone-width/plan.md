# Implementation Plan: The Phone Line's Wrap Is Stated at a Phone's Width (spec 061, #288)

**Spec:** docs/specs/061-place-line-wrap-at-phone-width/spec.md (0.3.0, approved at Gate A)
**Decisions:** none (no ADR; the ruling is the spec's decision 1)
**Created:** 2026-11-10

## Global Constraints

- One system example changes, with its helper and comments, in `spec/system/collection_row_place_spec.rb`. No stylesheet, view, helper, model, controller, migration or export change (FR-2). If the first measurement of the example differs from the spec's numbers by enough to break the 20px margin, stop and report: the plan then picks a longer line (spec FR-2), never a smaller margin.
- The example measures in headless Firefox through `open_in_narrow_frame` (`spec/support/narrow_frame.rb`); the scrollbar's width is read from the frame, never assumed (FR-3).
- The classic-scrollbar pin in `spec/support/system.rb` stays. Task 3's overlay run edits it temporarily and reverts it; nothing of that edit is committed.
- Spec types are tagged explicitly; multi-expectation examples use `:aggregate_failures` (CLAUDE.md, Specs). RuboCop's `RSpec/ExampleLength` maximum is 15 lines.
- Do not check prose documents from RSpec (`.claude/rules/testing.md`): AC-2.1 and AC-2.2 are verified by reading and recorded in `verification.md`.
- Core code names no collectible; this plan touches no core file, but the example's comments are tests' and may name the set.
- No `sleep`, no `any_instance_of`; one git operation per Bash call; Conventional Commits ending with the attribution line the session's system reminder gives. Run Ruby through `script/worktree/with_mise bin/…` (bare `ruby` is macOS Ruby 2.6, #289).

---

## Goal

The phone line's criterion says what phones do: a no-location line wider than its cell wraps instead of scrolling at a 360px content width, and its example (the PLST · PCY-132 · Etched · NM · EN line) proves it with a measured margin of at least 20px that a scrollbar setting can't flip.

---

## Phase 1: The example (Story 1, Decisions 1–2)

**Implements:** FR-1, FR-3 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3 (met by the existing examples), AC-1.4
**Files:** `spec/system/collection_row_place_spec.rb`
**Interfaces:** Consumes `open_in_narrow_frame(path, width:, ready:, height: 800)` returning `[innerWidth, fits]`, `within_narrow_frame`, `system_sign_in_as`, `owned_printing(name, account:, set:, number:, quantity:, finish:, condition:, ...)` (`spec/support/collection_helpers.rb`). Produces `line_measures` (private to the file): `{ room:, height:, unwrapped:, scrollbar: }` for the first `.c-table__sub` in the narrow frame, called from the top page after `open_in_narrow_frame`.

Tasks 1–3 go to one implementer, each its own commit except the overlay run (no commit), finished before Phase 2 starts. The shared test database: no second test run while it works.

### Task 1: The example, red on the old line

- [ ] In `spec/system/collection_row_place_spec.rb`, add the helper after `measures` (it follows `measures`'s pattern: it is called from the top page, after `open_in_narrow_frame`, because inside `within_narrow_frame` the `narrow` element doesn't exist):

```ruby
  # Measured in the narrow frame (spec 061 decision 2): the phone line's room (its clientWidth while its text wraps), its
  # height, its unwrapped width (a range over its contents with wrapping switched off, then restored) and the page's
  # scrollbar width (15px classic, 0 overlay). Room grows one for one with the frame's content width, so
  # room + scrollbar is the room a 360px content width gives.
  def line_measures
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const view = document.getElementById("narrow").contentWindow
        const doc = view.document
        const line = doc.querySelector(".c-table__sub")
        const room = line.clientWidth
        const height = line.getBoundingClientRect().height
        const before = line.style.whiteSpace
        line.style.whiteSpace = "nowrap"
        const range = doc.createRange()
        range.selectNodeContents(line)
        const unwrapped = range.getBoundingClientRect().width
        line.style.whiteSpace = before
        return { room, height, unwrapped, scrollbar: view.innerWidth - doc.documentElement.clientWidth }
      })()
    JS
  end
```

- [ ] Replace the example at `it "wraps the line at 360px for a five-character set code, ..." do # AC-1.8` (the whole `it` block, line 93 to its `end`) with this one, **still using the old line** ("pmh3a", "146", "foil") so the margin assertion is seen to fail first:

```ruby
    it "wraps a line wider than its room at a phone's 360px content width, with no sideways scroll and no place", :aggregate_failures do # spec 061 AC-1.1, AC-1.2
      owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "pmh3a"), number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
      visit table_path
      expect(open_in_narrow_frame(table_path, width: 360, ready: "tbody tr")).to eq([ 360, true ])
      within_narrow_frame do
        expect(page).to have_no_css("th", text: "Location", visible: :all)
        expect(find(".c-table__sub", visible: :visible).text).to end_with("PMH3A · 146 · Foil · NM · EN")
      end
      seen = line_measures
      expect(seen[:height]).to be >= 20
      margin = seen[:unwrapped] - (seen[:room] + seen[:scrollbar])
      expect(margin).to be >= 20, "margin #{margin.round(1)}: unwrapped #{seen[:unwrapped].round(1)}, room #{seen[:room]}, scrollbar #{seen[:scrollbar]}"
    end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/collection_row_place_spec.rb -e "wraps a line wider than its room"`. Expected: **fails** on the margin assertion, with the message "margin -7.6: unwrapped 153.4, room 146, scrollbar 15" (the spec's probe: 153.4 − (146 + 15); RSpec prints the custom message in place of its own "expected: >= 20" text). If it fails any other way (line not found, `end_with` text), fix the example and re-run until the only failure is the margin.
- [ ] Commit (`test(system): measure the no-location phone line's wrap at a phone's width, red (spec 061, #288)`). The red commit is deliberate (TDD gate); the next task makes it pass.

### Task 2: The line that wraps on a phone, green

- [ ] In the same example change the lot and the text to the spec's line and nothing else:

```ruby
      owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "plst"), number: "PCY-132", quantity: 9_999, finish: "etched", condition: "near_mint")
```

and `expect(find(".c-table__sub", visible: :visible).text).to end_with("PLST · PCY-132 · Etched · NM · EN")`.

- [ ] Run the example. Expected: **passes** (the numbers are read in Task 3, not here). If the finish label isn't "Etched" or the margin is under 20, stop and report (Global Constraints).
- [ ] Run the whole file: `script/worktree/with_mise bin/rspec spec/system/collection_row_place_spec.rb`. Expected: all examples pass (the new example replaces one, so the count is unchanged).
- [ ] Commit (`test(system): wrap the phone line's proof on a PLST, PCY-132, Etched line (spec 061 AC-1.1, AC-1.2, #288)`).

### Task 3: Comments, and the overlay run

- [ ] Update the file's header comment (lines 3–6) to cite spec 061: after "a table with no location is unchanged (AC-1.7)." add "A no-location line wider than its room wraps at a phone's 360px content width (spec 061 AC-1.1, AC-1.2, which restates AC-1.8)." Keep the AC-1.6 sentence.
- [ ] Reword the factory comment above `own_in` (lines 14–15), which now reads "The set code is pinned to a realistic three-character one: the factory's sequence makes it up to five characters late in a full run, which legitimately wraps the phone line at 360px (see the AC-1.8 example)." to: "The set code is pinned to a realistic three-character one: the factory's sequence makes it up to five characters late in a full run (such as `S2000`), which can wrap the line in the suite's 360px frame, whose classic scrollbar leaves 345px, and not on a phone (spec 061)."
- [ ] Run RuboCop on the file: `script/worktree/with_mise bin/rubocop spec/system/collection_row_place_spec.rb`. Expected: no offenses.
- [ ] Commit (`test(system): cite spec 061 in the place spec's comments (#288)`).
- [ ] **The classic and overlay runs (AC-1.4), no commit.** Temporarily add, right before the final `expect(margin)` in the new example, `puts "NUMBERS #{seen.inspect} margin #{margin}"` (RuboCop's `RSpec/Output` will report it after the edit; that is expected, leave it, the revert removes it). Run `script/worktree/with_mise bin/rspec spec/system/collection_row_place_spec.rb -e "wraps a line wider than its room"` and keep the `NUMBERS` line as the **classic** run (scrollbar 15, room about 146, unwrapped about 184.1, margin about 23.1). Then edit `spec/support/system.rb` line 39 to `options.add_preference("ui.useOverlayScrollbars", 1) # 1 = overlay`, run the same command again and keep its `NUMBERS` line as the **overlay** run (scrollbar 0, room about 161, unwrapped about 184, height 32, margin about 23, and that the example passed). Then revert both edits: `git checkout -- spec/support/system.rb spec/system/collection_row_place_spec.rb` (only uncommitted edits go: the example was committed above), and confirm `git status` is clean. Report both `NUMBERS` lines in the batch's summary. If the example fails or the overlay scrollbar width is not 0, stop and report.

---

## Phase 2: The documents (Story 2)

**Implements:** AC-2.1, AC-2.2 | **Satisfies:** AC-2.1, AC-2.2
**Files:** `docs/architecture/collection-and-lots.md`, `docs/specs/061-place-line-wrap-at-phone-width/verification.md`
**Interfaces:** none (documents).

`docs/specs/README.md` already carries both rows (spec 061's and 048's "Superseded by" cell, spec commits ba734cc9 and bf8827e0); the supervisor re-reads them in Task 5. The distillation-log entry and the index status words are the `distill-feature` step's, not this phase's.

### Task 4: The area doc

- [ ] In `docs/architecture/collection-and-lots.md`, the **Place line** bullet (line 120): replace the end of the bullet, from "The phone line's wrap rule is the `c-table__sub` rule" to the end of the bullet, with:

```
The phone line's wrap rule is the `c-table__sub` rule of every table inside `.c-collection` below 640px, an account with no location's included, where a line wider than its cell wraps instead of scrolling the page: spec 048 AC-1.7's line ("MH3 · 146 · Foil · NM · EN") fits one line at 360px and 390px, a five-character code alone ("PMH3A · 146 · Foil · NM · EN", 153px) still fits a phone's 360px with about 8px to spare, and a line of The List ("PLST · PCY-132 · Etched · NM · EN", 184px against a room of 161px) wraps by 23px (spec 048 decision 4, AC-1.7; spec 061 AC-1.1 and AC-1.2, which restate spec 048 AC-1.8: its five-character claim held only with a classic scrollbar's 345px of content, and the example measures the margin at a phone's 360px whatever scrollbar the browser draws) (spec 033 decisions 1–3, AC-1.1–AC-1.6, AC-2.2; spec 048 AC-1.1–AC-1.7).
```

- [ ] In the **Sources** section, change the spec 048 line (line 251) so it reads "…: all, except AC-1.8, restated by spec 061 (a row's place line wraps; …" keeping the rest, and add after it a line: `- [Spec 061](../specs/061-place-line-wrap-at-phone-width/spec.md): all (the phone line's wrap, stated at a phone's width; it restates spec 048 AC-1.8 and leaves decision 4's ruling and AC-1.7 as they are).`
- [ ] Run `gh issue view 271 --json state` first (the spec calls it the issue that found the cause; list it as closed only if it is). Add `[#288](https://github.com/plainprogrammer/Collector/issues/288) and [#271](https://github.com/plainprogrammer/Collector/issues/271) (spec 061)` to the issues list in Sources (line 263), after the last closed issue entry and before "; open:".
- [ ] Verify by reading: `git grep -n "five-character" -- docs/architecture ':!.kamal/secrets'` shows only the new sentence. Commit (`docs(architecture): the phone line's wrap at a phone's width (spec 061, #288)`).

### Task 5: Verification notes

- [ ] Create `docs/specs/061-place-line-wrap-at-phone-width/verification.md` with: a table of each criterion (AC-1.1 to AC-2.2), how it was verified and the evidence: AC-1.1, AC-1.2 the example's name and its run (SHA, "passes"; the classic `NUMBERS` line from Task 3); AC-1.3 the two existing examples at `collection_row_place_spec.rb` ("fits one line under the name at 360px and 390px") passing; AC-1.4 the overlay `NUMBERS` line from Task 3 (scrollbar 0, room, unwrapped, height, margin; the classic line goes under AC-1.1 and AC-1.2) and that the pin edit was reverted (a clean `git status`); AC-2.1 and AC-2.2 by reading (the two index rows, spec 048's "Superseded by" cell, the area doc's bullet and Sources); and the deviations section ("none" or what changed). Say in the AC-2.2 row that its distillation-log entry is still owed by `distill-feature`. Do not add an `## Implementation review` heading: the review step adds it.
- [ ] Commit (`docs(specs): verification notes for spec 061 (#288)`).

---

## Self-review

- **Spec coverage:** FR-1 (Tasks 1–3), FR-2 (Global Constraints; the no-CSS rule; the stop-and-report on a thin margin), FR-3 (the helper reads `scrollbar`); AC-1.1, AC-1.2 (Tasks 1–2), AC-1.3 (existing examples, confirmed by the whole-file run in Task 2), AC-1.4 (Task 3, recorded in Task 5), AC-2.1 (index rows exist; Task 5 reads them), AC-2.2 (Task 4).
- **Placeholders:** none; each code step has its code, each document step its text.
- **Consistency:** `line_measures` returns `room`, `height`, `unwrapped`, `scrollbar`, used under those names in the example; the example's name is the one the `-e` filter uses.
- **Comments updated by this plan (`.claude/rules/code-documentation.md`):** the spec file's header comment and the factory comment (Task 3), and the new helper's comment (Task 1). No public code changes.
