# Verification: Add Cards from a Set by Collector Number (spec 026)

**Spec:** [spec.md](spec.md) v1.2.2 · **Plan:** [plan.md](plan.md) · **Branch:** `026-typed-entry` · **Issue:** [#43](https://github.com/plainprogrammer/Collector/issues/43)

## Rulings

By the maintainer, 2026-10-15, with the spec's approval: decision 3 (a line is number, quantity and finish; the finish defaults to the type's first in `finish_order`), decision 4 (each line adds at once) and decision 7 (no live preview of the match), each as recommended.

Made during execution, each recorded in its commit's body:

| Commit | Ruling | Why | If wrong |
|---|---|---|---|
| `e78a4b7` | A set or type parameter that isn't a string counts as absent | `{"a"=>"b"}.to_s` is a non-blank string, so a forged hash type narrowed the sets to none and the plan's own "ignores a type … that isn't a string" example failed | A non-string parameter is ignored rather than matching nothing |
| `bdbda03` | The signed-out examples create a user first | With no account at all the app sends a first visitor to sign up, not sign in (spec 004's first run) | Nothing; the first-run redirect is covered elsewhere |
| `bdbda03` | `spec/requests/admin/navigation_spec.rb` expects "Add by number" after "Export collection" on More, not in the avatar menu | Spec 026 v1.2.2 (Supersedes: spec 022 decision 6) adds the row to More only | The avatar menu would need the row too |
| `d758eb3` | AC-5.1's request-then-follow pairs go through a `loaded { … }` helper | The plan's draft was 18 lines against RuboCop's 15-line `RSpec/ExampleLength` | Only the example's shape differs |
| `6269b7a` | Add's cell is padded `calc(var(--space-4) + var(--space-1))`, not `var(--space-6)` | The label is a 16px line plus the field's 4px gap; 24px put Add 4px below the inputs in the screenshots, and there is no 20px token | Add sits a few pixels off the inputs |
| `6269b7a` | The data face on the number and quantity inputs is `.c-input .c-numentry__data-input` | The plan's single-class rule lost to the export's `.c-input input` font | Only the inputs' face |
| `6269b7a` | The choice's `c-list` loses its top border as well as its rows' | The plan removed only the rows' borders, leaving a stray rule under the prompt | Cosmetic |
| `6269b7a` | A one-language set reads "Language: EN" with only the code in the data face; AC-1.7's request example reads the text of `.c-numentry__set` instead of a raw HTML substring | The label in Plex Mono read as data | Cosmetic |
| `6269b7a` | The keyboard system example's three add-and-check steps go through an `add_line` helper | The plan's draft was 17 lines against `RSpec/ExampleLength` | Only the example's shape differs |
| Phase 8 | `spec/number_entry_core_spec.rb` joins `.rubocop.yml`'s `RSpec/DescribeClass` excludes, with the comment saying why | It checks a feature's files, not a class, as the other core specs do; the plan didn't list the exclusion and the first `bin/ci` failed on it | None beyond one config line |

The plan review's browser-only doubts all held in headless Firefox (Phase 7): Escape then Enter on the set field's suggestions submits the typed code; `f` on the focused finish select picks Foil; Enter on the select reaches the Stimulus controller; the rejected number ends up focused and selected after Turbo's autofocus; 12 lines fit 360px.

Decision 2's catalog-title label on the set suggestions (`Catalog.title_for`, shown only when more than one type is registered) has no example while only one type is registered.

## The suite

`bin/ci` on this branch, with the Phase 8 changes in the tree:

```text
✅ Setup passed
✅ Style: Ruby passed (494 files, no offenses)
✅ Security: Brakeman code analysis passed (no warnings)
✅ Security: Gem audit passed
✅ Security: Importmap vulnerability audit passed
1593 examples, 0 failures, 1 pending (the opt-in art agreement, spec/system/art_agreement_spec.rb:16)
✅ Tests: RSpec passed in 3m58.46s
✅ Continuous Integration passed in 4m13.45s
```

## Acceptance criteria

Request examples are in `spec/requests/number_entries_spec.rb`, model examples in `spec/models/number_entry_spec.rb` and `spec/models/number_entry/`, system examples (headless Firefox) in `spec/system/number_entry_spec.rb`.

| Criterion | Held by |
|---|---|
| AC-1.1 | `spec/system/number_entry_spec.rb:25` (collection → "Add by number", heading, `#number_entry_set:focus`); `spec/requests/number_entries_spec.rb:29`, `:40` |
| AC-1.2 | `spec/system/number_entry_spec.rb:56` (More → "Add by number" in a 360px frame); `spec/requests/number_entries_spec.rb:29` (the empty collection's link); screenshots `*-390-*.png` |
| AC-1.3 | `spec/models/number_entry/set_choice_spec.rb:9`; `spec/requests/number_entries_spec.rb:40` |
| AC-1.4 | `spec/requests/number_entries_spec.rb:51`; `spec/models/number_entry/set_choice_spec.rb:24`; `spec/system/number_entry_spec.rb:32` (set name shown, number focused) |
| AC-1.5 | `spec/requests/number_entries_spec.rb:51`, `:62`; `spec/models/number_entry/set_choice_spec.rb:62` |
| AC-1.6 | `spec/models/number_entry/set_choice_spec.rb:71` |
| AC-1.7 | `spec/requests/number_entries_spec.rb:69` |
| AC-1.8 | `spec/requests/number_entries_spec.rb:76`; `spec/models/number_entry/set_choice_spec.rb:30` |
| AC-1.9 | `spec/requests/number_entries_spec.rb:103` |
| AC-1.10 | `spec/requests/number_entries_spec.rb:373`, `:378` (`:public_catalog`) |
| AC-1.11 | `spec/requests/number_entries_spec.rb:89` (a language the set lacks), `:95` (a linked set whose entries are all retired); `spec/models/number_entry/set_choice_spec.rb:54`, `:80` |
| AC-2.1 | `spec/requests/number_entries_spec.rb:125`; `spec/models/number_entry_spec.rb:13` |
| AC-2.2 | `spec/requests/number_entries_spec.rb:125`; `spec/system/number_entry_spec.rb:32` (number focused after each add) |
| AC-2.3 | `spec/requests/number_entries_spec.rb:135`; `spec/system/number_entry_spec.rb:32` (47, Tab, 4, Enter) |
| AC-2.4 | `spec/requests/number_entries_spec.rb:141`; `spec/system/number_entry_spec.rb:32` (Tab, Tab, `f`, Enter on the select; Foil kept) |
| AC-2.5 | `spec/requests/number_entries_spec.rb:149` |
| AC-2.6 | `spec/requests/number_entries_spec.rb:156`; `spec/models/number_entry/line_form_spec.rb:24` |
| AC-2.7 | `spec/requests/number_entries_spec.rb:156`; `spec/models/number_entry/line_form_spec.rb:32` |
| AC-2.8 | `spec/models/number_entry/line_form_spec.rb:38` |
| AC-2.9 | `spec/requests/number_entries_spec.rb:164`; `spec/models/number_entry/line_form_spec.rb:44`, `:53`; the first choice focused in `choice-*.png` |
| AC-2.10 | `spec/requests/number_entries_spec.rb:175`; `spec/models/number_entry/line_form_spec.rb:53` |
| AC-2.11 | `spec/requests/number_entries_spec.rb:185`; `spec/models/number_entry_spec.rb:20` |
| AC-2.12 | `spec/requests/number_entries_spec.rb:185`; `spec/models/number_entry_spec.rb:28` |
| AC-2.13 | `spec/system/number_entry_spec.rb:32` (three lines from the keyboard alone); the focus ring on each field and button by `focus-number-1280-light.png`, `focus-quantity-1280-light.png`, `focus-finish-1280-light.png`, `focus-add-1280-light.png` |
| AC-2.14 | `spec/requests/number_entries_spec.rb:195` |
| AC-2.15 | `spec/requests/number_entries_spec.rb:202`; `spec/models/number_entry/line_form_spec.rb:120` |
| AC-3.1 | `spec/requests/number_entries_spec.rb:263` |
| AC-3.2 | `spec/requests/number_entries_spec.rb:273`; `spec/models/number_entry/line_spec.rb:10` |
| AC-3.3 | `spec/requests/number_entries_spec.rb:284`; `spec/models/number_entry/line_spec.rb:17` |
| AC-3.4 | `spec/requests/number_entries_spec.rb:290`; `spec/models/number_entry/line_spec.rb:28`, `:35`, `:42`; the "Changed in your collection" tag in `rejected-*.png` |
| AC-3.5 | `spec/models/number_entry/line_spec.rb:22` |
| AC-3.6 | `spec/requests/number_entries_spec.rb:302` |
| AC-3.7 | `spec/requests/number_entries_spec.rb:309`; `spec/models/number_entry_spec.rb:64` |
| AC-3.8 | `spec/requests/number_entries_spec.rb:317` |
| AC-3.9 | `spec/models/number_entry_spec.rb:57` |
| AC-4.1 | `spec/requests/number_entries_spec.rb:210`; `spec/models/number_entry/line_form_spec.rb:74`; `spec/system/number_entry_spec.rb:46` (focused, text selected `[0, 3]`, typing replaces it) |
| AC-4.2 | `spec/requests/number_entries_spec.rb:221`; `spec/models/number_entry/line_form_spec.rb:80` |
| AC-4.3 | `spec/requests/number_entries_spec.rb:231`; `spec/models/number_entry/line_form_spec.rb:89` |
| AC-4.4 | `spec/requests/number_entries_spec.rb:238`; `spec/models/number_entry_spec.rb:35` |
| AC-4.5 | `spec/requests/number_entries_spec.rb:248`; `spec/models/number_entry/line_form_spec.rb:101` |
| AC-5.1 | `spec/requests/number_entries_spec.rb:335` (full page loads, no scripting) |

## Requirements

| Requirement | Held by |
|---|---|
| FR-1 (core code) | `spec/number_entry_core_spec.rb:12` (the 18 files: 4 models, 4 controllers, the concern, the helper, 7 views and the Stimulus controller) and `:16` (none names `mtg`, `scryfall`, `magic`, `foil`, `nonfoil` or `etched`) |
| FR-5 | `docs/export-format/README.md` Coverage: `number_entries` and `number_entry_lines` "Left out"; `spec/export_format_document_spec.rb:62`, `:72`; AC-3.9's example. The format, schema, examples and version are unchanged |
| NFR Performance | `spec/requests/number_entries_spec.rb:351` (the same query count for a set of 1 entry and of 41), `:360` (the same for a number matched only without its leading zeros); the measurement below |
| NFR Security | AC-3.8's example (another account's line answers 404); the line form carries no `account_id` or lot id, only the entry's external key on a choice, checked by AC-2.10's examples |
| NFR Accessibility (360px) | `spec/system/number_entry_spec.rb:56`: the page with 12 lines fits a 360px frame without sideways scrolling |

## Measurement (NFR Performance)

The development catalog in this worktree is empty (0 entries; each worktree has its own databases), so the plan's runner script, which looks up MH3, can't run as written. Instead, `bin/rails runner` against development, inside one transaction that was rolled back: it inserted a synthetic catalog the size of the full English Magic catalog (900 sets of 110 entries, 99,000 `catalog_entries`, one of the sets `mh3` with `mtg_printings` offering nonfoil and foil), ran `ANALYZE`, created an account, and timed five adds of MH3 · 47 the way the plan's script does (`NumberEntry::SetChoice.new(text: "mh3", …)`, `NumberEntry::LineForm#valid?`, `NumberEntry.add!`), with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`. Intel Xeon E3-1270 v3 at 3.5 GHz, 4 cores, Fedora 44, Ruby 4.0.7.

| Add | Time |
|---|---|
| 1 (opens the list and the lot, first queries of the process) | 66.5 ms |
| 2 | 17.7 ms |
| 3 | 14.1 ms |
| 4 | 14.9 ms |
| 5 | 14.2 ms |

The lot held 5 copies afterwards; after the rollback the catalog was empty again. The query-count example above holds the count fixed whatever the set's size. A timing against Scryfall's real data is still open: a development catalog with the English bulk file loaded would give it.

## Hosted-door rules

1. **Source terms allow hosting:** no new catalog source.
2. **The operator is not the user:** no admin page or task shows the list or its lines (`app/views/admin` and `app/controllers/admin` don't name number entry).
3. **Collector choices are stored per account or user:** no instance setting or environment variable is added; the set, language and finish live in the page's URL.
4. **Bounded cost per account:** one `number_entries` row per account with a list, and one `number_entry_lines` row of about 100 bytes per added line until Done deletes them (or the account goes). No background work.

## Screenshots

[screenshots/](screenshots/), taken with a throwaway system spec (not committed) in headless Firefox, for a list of five lines (two foils and an etched one as finish badges, one line "Changed in your collection"):

- `set-1280-{light,dark}.png`: the set field, focused, above the list.
- `rejected-1280-{light,dark}.png`, `rejected-390-{light,dark}.png`: "No card numbered 999 in Modern Horizons 3 (EN).", the number focused and selected.
- `choice-1280-{light,dark}.png`, `choice-390-{light,dark}.png`: "More than one card matches 007. Choose one.", the first match focused.
- `focus-{number,quantity,finish,add}-1280-light.png`: the focus ring on each field and Add in tab order (AC-2.13).

The 390px shots are a 390px iframe, since headless Firefox won't open a window that narrow. Checked by eye against the design system: the line's fields sit in one row at 1280px with Add level with the inputs, and in two columns at 390px with Add full width; nothing scrolls sideways; the focus ring shows on every field and button in both themes; error text is `danger` on the page surface.
