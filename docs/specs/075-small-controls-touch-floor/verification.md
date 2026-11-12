# Verification: spec 075, small controls meet the touch floor on a coarse pointer

**Branch:** `075-small-controls-touch-floor` | **Issue:** [#316](https://github.com/plainprogrammer/Collector/issues/316) | **Spec:** [spec.md](spec.md) 0.3.2 | **Plan:** [plan.md](plan.md) 0.2.0

## Acceptance criteria

The system examples are in `spec/system/small_controls_touch_floor_spec.rb` (21 examples: the `[ 1280, 360 ]` loops make AC-1.2, AC-1.3, AC-1.5, AC-1.6, the pagers' Previous and the rows 1 and 14b two each). Run on 2026-11-11 with `bin/rspec spec/system/small_controls_touch_floor_spec.rb spec/system/select_touch_floor_spec.rb spec/system/deck_page_spec.rb spec/system/deck_proxies_spec.rb spec/system/deck_additions_spec.rb spec/system/card_page_spec.rb spec/system/deck_proxy_replacements_spec.rb spec/system/deck_bulk_shortcut_spec.rb spec/system/locations_spec.rb spec/system/location_bulk_shortcut_spec.rb spec/design_system_files_spec.rb`: **129 examples, 0 failures** (before the review's two added Previous examples; after them the new file alone is 21 examples, 0 failures). The red runs of the plan (before the CSS): Task 2, 40 examples with exactly two failures (`[ 40, 90 ]` against `[ 44, 90 ]`, AC-2.11's `nil` rule); Task 3, 5 examples with 3 failures; Task 4, the whole new file 19 examples with 17 failures (all by name: "the coarse-pointer rule … is not in the loaded stylesheets", AC-1.1 on the rule count), AC-1.3 passing. With the CSS (Task 5), the four-file run was 66 examples, 0 failures.

| AC | Proved by |
|---|---|
| AC-1.1 | "gives the small controls a coarse-pointer rule of their own that wins by source order": two coarse rules have the selector text `.c-btn--sm, .c-filter, .c-seg button`, the last is in `additions` at `var(--touch-floor)` and after `components.css`'s; the last `.c-btn--sm.c-btn--icon, .c-seg button` has `min-width: var(--touch-floor)`; `--touch-floor` is at least 44px |
| AC-1.2 | "draws every small control at least 44px high, the icon-only ones 44px wide" at 1280px and 360px: all 15 entries of the spec's `pages` (rows 2 to 15 split into routes) with every coarse rule applied and each listed control drawn; plus the flows "the status message's Undo" (row 16), "a visitor's Sign in" (row 1) and "a candidate's Other printings and Add buttons" (row 14b), each at both widths |
| AC-1.3 | "leaves a fine pointer's compact size where no page rule applies": under 36px for every small control with no page-rule ancestor, at both widths, nothing injected; it also asserts every listed control is drawn, so a wrong selector failed here before the CSS existed |
| AC-1.4 | "keeps every page whole at 360px with all the coarse rules": no overflow, no overlap, nothing past the right edge outside the filter row, measured over `main`, the header and `#status` |
| AC-1.5 | "adds no line to any row of controls" at both widths (a line is a cluster of vertically overlapping controls of the row; the first filter bar grows by at most 8px at 360px) |
| AC-1.6 | "levels the filter row's small button with its select, both at least 44px" at both widths on the collection (grid, bulk mode), card search and the proxy chooser |
| AC-1.7 | "changes no other control's size": every page at 360px, all coarse rules with and without the block's two |
| AC-1.8 | "notices a rule that grows another control" (number entry's Add button goes to 90px), "notices a row that gains a line" (bulk bar and number entry's language row, 360px) and "has a control under 44px without the block" |
| AC-2.1 | read: `docs/design-system/README.md` line 73 says every target is at least 44px with no exception, the small controls and the icon widths included; the compact sizes are the fine pointer's; the rules live in `components.css` (40px, overridden) and `additions.css`'s blocks, which must stay after it; the filter row centres what is not 44px; it points to this spec and keeps spec 072's selector detail |
| AC-2.2 | read: one bullet each in `Button.md`, `Chip.md`, `ViewSwitch.md`, `TableActions.md`, `BulkForm.md`, `Pager.md`, `AdminJobs.md`; the 40px sentences of `FilterSelect.md` and `NumberEntry.md` corrected. Previews unchanged (they load `additions.css`; no preview hard-codes 40px, see the grep below) |
| AC-2.3 | read: `docs/specs/README.md` has the 075 row and spec 072's "Superseded by" cell names it |
| AC-3.1 | `git diff --stat origin/main...HEAD -- app db config lib script`: one file, `app/assets/stylesheets/collector/additions.css`, 19 insertions, 5 deletions (the block, two corrected comments). No view, helper, controller, model, JavaScript, migration, export or other stylesheet changed |
| AC-3.2 | the 129-example run above, which includes spec 072's file (two examples re-premised), `deck_page_spec.rb` (AC-2.11 re-premised), `deck_proxies_spec.rb`, `deck_additions_spec.rb`, `card_page_spec.rb`, `deck_proxy_replacements_spec.rb`, `deck_bulk_shortcut_spec.rb`, `locations_spec.rb`, `location_bulk_shortcut_spec.rb` and `design_system_files_spec.rb` |

`bin/rubocop` (791 files, no offenses) and `bin/yard doc` (builds) pass. The full `bin/ci` runs on the push (a slot was asked for).

## The audit

Command, run 2026-11-11 from the repository root: `git grep -n -E "c-btn--sm|c-filter|c-seg" -- app ':!app/assets' ':!.kamal/secrets'`: 66 lines in 33 files (`c-filter` also matches `c-filterbar`), every file a place of the spec's table (the header, card search, the card and printings pages, the collection grid, table and bulk mode with its pager, number entry, the decks and deck pages, the proxy chooser, Locations, admin jobs and users, the scanner's candidate, sitting, picker and measurement panel, and the status message). The page rules: `git grep -n -E "min-height:(44px|var\(--touch-floor\))" -- app/assets/stylesheets/collector/additions.css` found the five families of the spec (`.c-locations`, `.c-decks`, `.c-deckpage .c-section__actions`, `.c-numentry__list`, the scanner's three), plus rules for other controls (the selects', the scanner's shutter, torch and photo, `.c-numentry__choice`, `.c-pick`), which no small control relies on.

## The supersession grep

Command: `git grep -n -E "40px|touch floor|pointer: ?coarse|apply_coarse_rules|inject_coarse|\[ 40, 90 \]|c-btn--sm|c-seg button|\.c-filter\b" -- spec docs/design-system ':!docs/specs' ':!docs/lessons' ':!.kamal/secrets' ':!spec/system/small_controls_touch_floor_spec.rb' ':!docs/design-system/previews'`, with "640px" lines removed. Most hits are markup (`c-btn--sm` in a document's HTML or a request spec's selector), not a size. The ones that say a size or read a rule: `select_touch_floor_spec.rb` (two examples changed, the rest unchanged), `deck_page_spec.rb` (AC-2.11 and one comment changed), `card_page_spec.rb`, `deck_additions_spec.rb`, `deck_proxies_spec.rb` and `deck_proxy_replacements_spec.rb` (read other rules or apply all coarse rules; unchanged and passing), `spec/support/coarse_pointer.rb` (hoisted). The narrower `(^|[^0-9])40px` over `spec` and `docs/design-system` (previews included) finds the README's own note that `components.css` still writes 40px, one comment of `deck_page_spec.rb` that says the same, and the new spec's own comments (`small_controls_touch_floor_spec.rb`, where it names the old 40px); nothing else, so no preview and no component document hard-codes a 40px small control.

## Decisions taken while implementing

- **The helpers were hoisted, not copied** (`spec/support/coarse_pointer.rb`: `inject_coarse` with `except:`/`needs:` by selector text and stylesheet, never by value, and `layout_report(roots:)`); spec 072's file calls them unchanged.
- **Plan selectors and fixtures changed while reading the views** (implementer, recorded in the commit bodies): `drawn?` and `small_controls` also read `value` (a `form.submit` button has no text), `other_controls` also measures the header (printings page had no non-small control in `main`), row 1 creates a user first (a visitor with no account is redirected to registration), row 14b adds a second printing and stubs `Scanner::OtherPrintings::SHOWN` so "Show 1 more" is drawn, the visitor context resizes the window to 1280px.
- **Row 14b's reading flow ran inside the 360px frame**, so the plan's stop-and-ask did not trigger; all candidate, "Other printings" and "Show 1 more" controls are measured at both widths.
- **The first proposal of AC-1.8's partner was wrong** (a taller small button cannot make AC-1.7 fail, which excludes small controls): patched to spec 0.3.2 before the plan was approved.
- **Table rows grow about 4px on a phone** (the "…" trigger is 46px with its border, 42px before): measured in the screenshots, allowed because no row gains a line (AC-1.5 counts lines; its 8px cap is on the collection's sticky filter bar, which grows by 4px).

## Evidence

[`screenshots/`](screenshots/): 56 JPEGs, seven pages (the collection grid, bulk mode, the collection table, card search, admin jobs, a deck page, number entry's list) × light and dark × 1280px (cropped to the top 460px and scaled to 1000px wide) and 360px (a frame, as a window can't go below 500px) × before and after. Factory data, placeholder card images. Headless Firefox has a fine pointer, so these are not photographs of a touch screen: both states apply every `(pointer: coarse)` rule of the shipped stylesheet in source order (the selects' 44px included); "before" leaves out the block's two rules, so the small controls stay at the export's 40px, and "after" applies them. A mouse sees no change.

## Implementation review

**SPEC-ALIGNED WITH MINOR FINDINGS** (Opus, read-only, Mode B, over `origin/main..HEAD`; no blocking or major finding, 4 minor, 4 nits). The coverage matrix found evidence for AC-1.1 to AC-3.2 and FR-1 to FR-4 and a way for each new example to fail (AC-1.8's three partners, the block-removed run, a `needs:` that fails by name before the CSS). Taken:

- **Minor 1** (AC-1.2's "draws each listed control" was only partly enforced at 360px, and "Previous" was never drawn): the `narrow:` lists of the collection grid and bulk mode gained Filter, the view switch and the pager; two examples (one per width) visit page 2 of the card search, the printings page and the admin failed list and expect a drawn "Previous" at 44px; `make_fixtures` makes two failed jobs.
- **Minor 2** (the spec's Error Scenario says the README tells an author to add the page to the audit; it did not): the README's Touch rule now says it and links the spec.
- **Minor 3** (`apply_coarse_rules`' comment said `needs` takes strings only): corrected to `[Array<String, Hash>]`, pointing to `inject_coarse`.
- **Nit 4** (this document overclaimed in three places: the 40px grep, the +4px table rows, the screenshot scale): corrected above.
- **Nit 5** (the README's page-rule list said "the scanner's sitting" only, and did not link the spec): corrected.
- **Nit 6** (the block's comment didn't say where it is documented): "Documented in the README's Touch rule." added.
- **Nit 7** (AC-2.11 checked the rule's text, not that the token resolves): it now also expects `--touch-floor` to be at least 44px.
- **Nit 8** (the new file is heavy, about 60 page or frame loads per AC-1.5 example, and `spec/support/runtime_log.txt` doesn't list it): not changed; refresh the log only if GitHub's shard times differ by more than a minute.

The review did not re-run the suite (read-only); the full run is the push's `bin/ci`.


## Distillation

`distill-feature` (state 2, before the merge): spec 075 changes the design system's rules, which live in `docs/design-system/README.md` and its component documents (the same home as specs 063 and 072), so no document under `docs/architecture/` has a statement to add or rewrite and no area doc's Sources or Distillation log gains a row; the README's Touch rule and the nine component documents were written with the implementation (Task 6, AC-2.1, AC-2.2). The index row reads Frozen, by the design system, with Plan "retirement owed"; the spec's header carries its frozen line; spec 072's "Superseded by" cell names this spec. `CLAUDE.md` restates no rule this feature changed (its design-system paragraph points to `docs/design-system/`). No ADR was proposed: the ruling is decision 1 of the spec, taken by the maintainer on 2026-11-11. The plan is retired in a housekeeping pull request after this one merges.
