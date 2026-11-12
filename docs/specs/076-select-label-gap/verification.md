# 076: a select's label keeps a gap to its select (issue #317)

A direct fix of [#317](https://github.com/plainprogrammer/Collector/issues/317). There is no `spec.md` and no `plan.md`: the coordinator approved the route (a bug with a one-rule fix, a failing example first) under the maintainer's delegation, and the number stays accounted for by this folder and its row in `docs/specs/README.md`.

## What changed

- `app/assets/stylesheets/collector/additions.css`, inside the "Select inside the filter bar" block only (the touch-floor rules of spec 072 and #316 are untouched): `.c-select { display: inline-flex; align-items: center; gap: var(--space-2); }`. The visible Language name on number entry (`c-field__label`) is inline text inside the wrapping `<label class="c-select">`, so it touched the select; the component now spaces it, with no page rule. A `c-sr` name is absolute and takes no part in the row.
- `docs/design-system/components/FilterSelect.md` (markup and a new bullet) and `NumberEntry.md` (one bullet).
- `spec/system/select_label_gap_spec.rb`.

## Test first

- `test(design-system): a select's label keeps the gap to its select, red (#317)` (`bbbe8bc0`): the two Language examples (desktop, 360px frame) failed with `expected 0 to be within 0.5 of 8` (the `--space-2` token, resolved in the browser by a probe element). The six hidden-label guards passed, as they should: they measure that the select of Location (collection), Set (card search) and Set (proxy chooser) starts where its label starts, so a `c-sr` name put in flow would fail them (it would push the select right by the gap).
- `fix(design-system): a select's label keeps a gap to its select (#317)` (`6d8198b9`): all 8 examples green.

## Audit of every `c-select`

`git grep -n "c-select" -- app ':!.kamal/secrets'`:

| Use | Name | Measured |
| --- | --- | --- |
| Number entry, Language (`_chosen_set.html.erb`) | visible `c-field__label` | gap 0 before, 8px (`--space-2`) after; desktop and 360px |
| Collection, Location (`_location_select.html.erb`, also in bulk mode's filter row) | `c-sr` | select offset 0 from its label, desktop and 360px (collection page); the bulk row renders the same partial |
| Card search, Set (`catalog/entries/index.html.erb`) | `c-sr` | offset 0, desktop and 360px; screenshots byte-identical before and after |
| Proxy chooser, Set (`decks/proxies/choose.html.erb`) | `c-sr` | offset 0, desktop and 360px (examples only; no screenshot) |

The issue also names a collection "Sort" select: there is no `c-select` Sort in the app, so there is nothing to check. Every use is a flex item (`c-filterbar__filters` or `c-numentry__language`), so `inline-flex` is blockified to the same box it had.

## Tests run

- `bin/rspec spec/system/select_label_gap_spec.rb spec/system/select_touch_floor_spec.rb spec/system/number_entry_spec.rb spec/system/design_system_deck_rules_spec.rb spec/system/deck_proxies_spec.rb spec/system/catalog_search_spec.rb spec/system/collection_location_filter_spec.rb spec/system/narrow_bulk_pages_spec.rb`: 61 examples, 0 failures, on the final code (spec 072's touch-floor examples and the filter-bar layouts among them).
- Earlier, before the `inline-flex` change: 49 examples (the new spec, spec 072's, number entry, deck rules and proxies) and 40 more (collection, location filter, bulk mode, views, table fit), 0 failures.
- The full suite runs in CI.

## Screenshots

In `screenshots/`, "before" emulated by injecting the old behaviour (`.c-select { display: inline; gap: 0 }`) as a `<style>`, not built from `main`; factory data, placeholder card images, both themes set by `data-theme`; 360px through the narrow frame. Names: `<page>-<width>-<theme>-<before|after>.jpg`.

- Number entry: `number-entry-desktop-*`, `number-entry-360-*`, and `number-entry-row-desktop-*` (the language row alone, to see the 8px).
- Card search and collection: `card-search-*`, `collection-*` (unchanged: the card-search pairs are byte-identical; the collection pairs differ only in the factory set code, S3 against S1, between runs).

I looked at the number entry pairs in light and dark at both widths (the label no longer touches the select; "Change set" wrapping at 360px is as before) and at the collection and card search 360px and desktop shots.

## Implementation review

SPEC-ALIGNED WITH FINDINGS

Read-only review on Opus (one round) of `git diff origin/main...HEAD`, against the issue (there is no spec). No blocking or major findings. Findings and what was done:

- Minor, use `inline-flex`: a future `.c-select` in normal flow stays inline as before. Done (`d8da4e4c`).
- Nit, spec created a `deck` and a second-language printing for every example; the comment cited a non-existent "AC"; `hidden_label_names` repeated the page keys. Done (`d8da4e4c`).
- Minor, `FilterSelect.md`'s Markup line named only the hidden name; `NumberEntry.md`'s "every select with one" was ambiguous. Done (`ddc24a5a`).
- Minor, the index row's Status was not a defined word and `verification.md` did not exist yet. Row now says "Approved (a direct fix …)"; this file is it.
- Minor, no proxy chooser or bulk-mode screenshots, and the issue's "Sort". Covered by the geometry examples and the audit above; no screenshot added.
- Nit, the block heading "Select inside the filter bar" no longer describes number entry's language row. Not changed: the issue and `FilterSelect.md` name the block by it, and a rename would touch #316's neighbouring edits in the same file.
- Nit, the collection shot pairs differ only in the factory set code. Stated above.

## Distillation

`distill-feature` ran before the pull request: no area doc under `docs/architecture/` covers the design system (the index lists it "no area doc", as for spec 044), so nothing was written there; the rule's current home is `FilterSelect.md` and `NumberEntry.md`, updated in this branch. There is no spec to freeze and no plan to retire, so the index row stays "Approved" until the merge. No ADR is proposed: the change is one rule in the component.
