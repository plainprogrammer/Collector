# Verification: Feature 068, Proxies in a Deck Zone

**Spec:** [spec.md](spec.md) (v0.4.0) · **Plan:** [plan.md](plan.md) · **Issue:** [#254](https://github.com/plainprogrammer/Collector/issues/254) · **Pull request:** [#313](https://github.com/plainprogrammer/Collector/pull/313)

Each acceptance criterion with the spec example (or the document check) that proves it. A path is a spec file; a quoted name is the example's title or the describe it sits in. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`), except the export format document's own checks.

## Acceptance criteria

### Story 1: Add a proxy to a zone

| AC | Proved by |
|---|---|
| AC-1.1 | `spec/requests/deck_pages_spec.rb` "gives each zone head an Add a proxy link, and the page no form" |
| AC-1.2, AC-1.3 | `spec/requests/deck_proxies_spec.rb` "the chooser" (title, detail page, search, Choose links, type and retired filtering, "Showing 10 of 12 printings", 12 cards a page); `spec/models/catalog/search_spec.rb` "lists only the printings of the collectible type it is given" |
| AC-1.4 | `spec/requests/deck_proxies_spec.rb` "the form" (finish options in the vocabulary's order, nothing chosen, the only finish chosen, none for a printing that lists none, labels) |
| AC-1.5, AC-1.6 | `spec/requests/deck_proxies_spec.rb` "the create" (notice, row, no lot, merge keeps the id); `spec/models/deck/proxy_spec.rb` "merges an add into the proxy of the same zone, printing and finish"; `spec/system/deck_proxies_spec.rb` "adds a proxy through the chooser and the form" |
| AC-1.7, AC-1.10 | `spec/requests/deck_proxies_spec.rb` "what is 404" (another account's deck, a place, a zone, `12abc`, a zone key the deck lacks, an unknown, retired, other-type or token entry, a deck of an unregistered type) and the signed-out example |
| AC-1.8, AC-1.9 | `spec/models/deck/proxy/addition_spec.rb`; `spec/requests/deck_proxies_spec.rb` "answers 422 with the field's sentence…", "refuses an add past 9,999…"; `spec/models/deck/proxy_spec.rb` "refuses an add past 9,999" and "wins a race on the unique index by merging" |
| AC-1.11 | `spec/requests/deck_proxies_spec.rb` "reads no account, zone id, kind or user from the request" |

### Story 2: See proxies in the zone table and the heads

| AC | Proved by |
|---|---|
| AC-2.1, AC-2.2, AC-2.3 | `spec/models/deck/page_spec.rb` "proxies (spec 068)"; `spec/requests/deck_pages_spec.rb` "proxies (spec 068 Story 2)" (tag, Owned 0, Total, heads, dash, "0 proxy" in an empty zone) |
| AC-2.4, AC-2.5, AC-2.11 | `spec/system/deck_page_spec.rb` (Owned and Proxy hidden below 640px with the tag in the line under the name; Cost, Owned, Proxy, Total and menu share edge and width at 1280px; no overflow at 360, 640, 768 and 1280px in both themes with a four-digit proxy count, a 60-character name, a six-symbol cost, a marker and the menu; menu trigger touch size, see Deviations) |
| AC-2.6, AC-2.7 | `spec/requests/deck_pages_spec.rb` (menu items, separator, the finish named for two finishes, an empty cell for a row with no proxy, links and no `form`) |
| AC-2.8, AC-2.9 | `spec/requests/deck_pages_spec.rb` "shows a proxy of a retired printing and a legality marker on a proxy row" |
| AC-2.10 | `spec/models/deck/page_spec.rb` (3 statements with nothing, 6 with lots and proxies, 6 with more: spec 066's 2 and 5 plus one); `spec/requests/query_counts_spec.rb` "keeps the deck page's and the Decks page's queries the same with six proxies as with one" |
| AC-2.12 | `spec/requests/deck_pages_spec.rb` (the tag's markup); `docs/design-system/components/ProxyTag.md` read |

### Story 3: Change a proxy's quantity or remove it

| AC | Proved by |
|---|---|
| AC-3.1 to AC-3.7 | `spec/models/deck/proxy_spec.rb` "#change_quantity!"; `spec/requests/deck_proxies_spec.rb` "changing a proxy" and "removing a proxy" (page, save, same quantity writes nothing, refusals with what was typed, nothing else touched, confirmation page, removal of one finish only, 404 for a removed or foreign proxy) |

### Story 4: A proxy is never owned and changes only by hand

| AC | Proved by |
|---|---|
| AC-4.1 | `spec/requests/deck_pages_spec.rb` "counts no proxy in the collection, the card page or an export's lots" |
| AC-4.2, AC-4.3 | `spec/models/lot_proxy_isolation_spec.rb` (add, move, edit, bulk move, number entry, removal of a copy, a retired printing) |
| AC-4.4 | `spec/requests/decks_spec.rb` "removing a deck with proxies" ("still refused while a zone holds a lot, whatever its proxies") |

### Story 5: The Decks page and removing a deck

| AC | Proved by |
|---|---|
| AC-5.1 | `spec/models/deck/listing_spec.rb`; `spec/requests/decks_spec.rb` "shows Cards as owned plus proxy, Owned, and the Proxy tag or a dash" |
| AC-5.2, AC-5.2a | `spec/system/decks_spec.rb` (360px fold; 640, 768, 1280px in both themes, tag and buttons don't overlap) |
| AC-5.3 | `spec/models/deck/listing_spec.rb` (4 statements: the decks, their locations, the copies, the proxies); `spec/requests/query_counts_spec.rb` |
| AC-5.4, AC-5.5 | `spec/requests/decks_spec.rb` "removing a deck with proxies"; `spec/requests/deck_proxies_spec.rb` "answers 404 for every proxy page of a deck removed meanwhile" |

### Story 6: Changing a deck's format moves proxies into Considering

| AC | Proved by |
|---|---|
| AC-6.1 to AC-6.8 | `spec/models/deck/format_change_spec.rb` "proxies (spec 068 Story 6)" (move, merge keeping the Considering proxy, own row kept, several dropped zones become one, the 9,999 refusal naming the proxy, the lots' refusal first, no proxy sentence when none moved, rollback, a deck with no Considering row); `spec/requests/deck_formats_spec.rb` "proxies (spec 068 AC-6.3, AC-6.4)" (notice wording, "1 proxy", the 422 alert) |

### Story 7: Proxies in the export and the import

| AC | Proved by |
|---|---|
| AC-7.1, AC-7.2 | `spec/models/collection_export_spec.rb` "proxies (spec 068 Story 7)" (the list, order, no id or time, other accounts' excluded, one statement however many, a type the instance no longer has) |
| AC-7.3 | `spec/export_format_examples_spec.rb` "proxies (spec 068)" (each variant exactly one problem; `valid/proxies-v4.json`; same collection; 79 invalid, 23 comparison examples), `spec/export_format_document_spec.rb` (Coverage rows, left-out columns), `spec/models/export_format/rules_spec.rb` "proxies (spec 068 decision 18)"; the schema copies are byte-identical (`spec/models/export_format/rules_spec.rb`); `docs/export-format/README.md` read |
| AC-7.4 | `spec/requests/collection_import_proxies_spec.rb` "restores a collection's proxies into a fresh account…"; `spec/models/collection_import/round_trip_spec.rb` over `valid/proxies-v4.json` |
| AC-7.5 | `spec/models/collection_import_proxies_spec.rb` "the whole file's refusals"; `spec/requests/collection_import_proxies_spec.rb` "refuses a version 4 file without proxies" |
| AC-7.6 | `spec/models/collection_import_proxies_spec.rb` "the problem rows"; `spec/requests/collection_import_proxies_spec.rb` "lists a proxy row with problems as 'Proxy N'" |
| AC-7.7, AC-7.9 | `spec/models/collection_import_proxies_spec.rb` "the outcomes"; `spec/requests/collection_import_proxies_spec.rb` "previews a Proxies section…", "refuses an apply without the box, and applies with it" |
| AC-7.8 | `spec/requests/collection_import_proxies_spec.rb` "leaves the proxies of a version 3 file's collector alone and says so"; `spec/models/collection_import_proxies_spec.rb` "judges nothing for a file older than version 4" |
| AC-7.10, AC-7.11 | `spec/requests/collection_import_proxies_spec.rb` (the notice, the same row survives, rows the model accepts, no working state cleared for a proxy-only change, cleared when a lot changes, a second apply is nothing to change) |
| AC-7.12 | `spec/requests/collection_import_proxies_spec.rb` "makes the preview stale when a proxy changes between the preview and the apply" |
| AC-7.13 | `spec/requests/collection_import_proxy_timing_spec.rb` (see Measured numbers) |
| AC-7.14 | `spec/collection_export_core_spec.rb`, `spec/collection_import_core_spec.rb`, `spec/import_apply_core_spec.rb`, `spec/deck_core_spec.rb` |

### Story 8: The data and the guards

| AC | Proved by |
|---|---|
| AC-8.1, AC-8.2 | `spec/models/deck/proxy_spec.rb` (what the model refuses, the NULL-finish unique index, the check constraint); `db/schema.rb` read |
| AC-8.3 | `spec/requests/deck_proxy_tenancy_spec.rb` (every page and verb from another account's session; no admin page shows a deck) |
| AC-8.4 | `spec/models/deck/proxy_spec.rb` "is removed with its zone and its deck, and deleted with the account"; `spec/models/account_spec.rb` (the association order) |
| AC-8.5 | `spec/backup_guards_spec.rb` passes unchanged; neither `docs/backup-restore.md` nor `README.md` lists the primary database's tables, so no backup document needed a change (read) |
| AC-8.6 | `script/upgrade/seeds/next.rb` carries a proxy; `ruby script/upgrade/guard.rb` passes; `spec/script/upgrade/seeds_spec.rb` and `seed_exceptions_spec.rb` pass; the upgrade smoke itself runs in CI (it needs a container engine) |
| AC-8.7 | `spec/deck_core_spec.rb` (48 files, none naming a game, source, format key or zone but `considering`) |

### Story 9: The pages follow the design system

| AC | Proved by |
|---|---|
| AC-9.1 | `spec/system/deck_proxies_spec.rb` (the chooser, the form, the change page and the removal page at 360, 640 and 1280px in both themes, with a 60-character name); `spec/requests/deck_proxies_spec.rb` (labels, `aria-describedby`) |
| AC-9.2 | `docs/design-system/components/{DeckPage,DecksIndex,ProxyTag,AddProxy}.md`, `README.md`, `previews/AddProxy.html` and `AddProxyPhone.html` read |
| AC-9.3 | `app/assets/stylesheets/collector/additions.css` (one new rule under its own heading comment, tokens only); `spec/design_system_files_spec.rb` passes |

## Measured numbers

**Statement counts** (as run): the deck page 3 statements with no lot and no proxy, 6 with lots and proxies and 6 with more (spec 066's 2 and 5 plus the proxies' one); the Decks page 4 (was 3); the export reads the proxies in one statement whatever their number.

**Timing** (`SCANNER_TIMING=1 bin/rspec spec/requests/collection_import_proxy_timing_spec.rb`, one run; a 31.4 MB file of 50,000 lots, 20,000 proxies, 300 places, 100 decks and 300 zones; the harness's memory note is in the deck timing spec's header: the process's resident set, reported and flagged, not asserted):

| Scenario | Seconds | Memory growth | Peak | Write transaction | Bar |
|---|---|---|---|---|---|
| Preview into an empty account | 12.63 | +454 MB | +454 MB | 0.16 s | under 30 s, 500 MB |
| Apply into an empty account | 13.63 | +311 MB | +311 MB | 1.59 s | under 30 s, transaction under 4 s |
| Export (50,000 lots, 20,000 proxies) | 1.15 | +6 MB | +18 MB | n/a | under 10 s, 300 MB |
| Preview of the changed file | 14.05 | −102 MB | +33 MB | 0.38 s | under 30 s, 500 MB |
| Apply of the changed file (every lot and proxy changes) | 15.95 | +190 MB | +190 MB | 3.45 s | under 30 s, transaction under 4 s |

No bar was missed. The changed apply's write transaction, 3.45 s, is the closest to its bar (4 s, below SQLite's 5 s busy timeout), as the deck timing spec's own numbers were. The first preview's 454 MB growth is under the 500 MB bar with thin headroom, the same caveat spec 062's verification recorded.

## Deviations from the plan, and rulings

- **The row menu's touch size (AC-2.11).** Headless Firefox has a fine pointer, so a 44px coarse-pointer measurement can't be taken. The design system gives a small icon button a 40px coarse floor (`components.css`), which the card page's menus share; the example asserts that stylesheet rule (at least 40px) and the trigger as drawn (at least 30px on a fine pointer). The new pages' buttons meet the 44px floor at every pointer (`.c-decks .c-btn`), and their selects meet it on a coarse pointer by the rule `@media (pointer: coarse) { .c-decks .c-select select, .c-decks .c-field select { min-height: var(--touch-floor) } }`, verified by reading that rule from the loaded stylesheets because headless Firefox can't emulate a coarse pointer. If a literal 44px is wanted for the row trigger, its markup must drop `c-btn--sm`: a maintainer's call, recorded here.
- **One CSS rule not in the plan.** `.c-decks .c-pagehead__title { overflow-wrap: anywhere; }` (T10): the Change proxy count page's title holds a card name of up to 60 characters with no space, and the system spec failed at every width without it. It is under its own heading comment and documented in `AddProxy.md`.
- **Capybara reads the inline-flex tag as two lines** ("Proxy\n3"), so system-spec text matchers use `/\AProxy\s+3\z/`; the DOM, and the request specs, hold "Proxy 3".
- **Existing examples changed, each a supersession the spec names** (spec 068 "Supersedes and updates"): spec 066's head texts, the AC-1.6 example (rewritten), the AC-4.2 selector, the five-column header lists (six now) in `spec/requests/deck_pages_spec.rb`, `spec/requests/decks_spec.rb` and `spec/system/deck_page_spec.rb`; `plan_spec`'s expected fingerprint parts (a version 4 plan carries the proxies' part); and the import helpers and specs that build version 4 files by hand (`proxies` is required now).
- **The chooser and Add a proxy touch fix (implementation review follow-up).** The chooser's `main` lacked `c-decks`, so its buttons had no 44px floor and a 60-character deck name in its heading wrapped nowhere; it carries `c-decks` now, and the AC-9.1 width examples use a 60-character deck name with no space and a floor example. The deck page's "Add a proxy" link (40px on touch) gets the 44px floor from one rule, `.c-deckpage .c-section__actions .c-btn`, under its own heading comment in `additions.css`, with system examples in `spec/system/deck_page_spec.rb`; as with the Decks pages' rule it applies at every pointer, so the examples measure 44px as drawn.
- **The touch-floor rule for selects (implementation review follow-up 2).** The chooser's Set select was 40px and the form's Finish select 36px on a touch screen; one `@media (pointer: coarse)` rule in `additions.css`, under its own heading comment, lifts both to `var(--touch-floor)`, and also the Change format page's Format select (spec 064), which shares `.c-decks`. Raising the select floor app-wide is out of scope. The example in `spec/system/deck_proxies_spec.rb` reads the rule, not a drawn size, since a fine pointer draws the old height.
- **The `deck_core_spec` file count** is red between T1 and T20 by design (the plan resets it to 48 in T20).
- **The `private_class_method` / constant details** of the plan were adapted where the real code differed (`CollectionImport::Problem` named in full in the compact module; `proxy_attributes` returns a hash); no behaviour differs from the spec.

## Documents verified by reading

`docs/architecture/collection-and-lots.md`, `data-portability.md`, `tenancy-and-accounts.md` (each new statement carries its source), `CLAUDE.md`'s deck sentence, `docs/export-format/README.md` (the Proxies section, the rules, "same collection", versions, Coverage, Examples), `docs/design-system/**` (T22), `docs/releasing.md`'s upgrade note, `docs/specs/README.md`'s rows (spec 068 and the supersessions in both directions).

## Screenshots

Kept in `screenshots/` (factory data, placeholder printings; headless Firefox, light and dark set explicitly): `deck-page-wide-light.jpg`, `deck-page-wide-dark.jpg`, `deck-page-phone-light.jpg`, `deck-page-phone-dark.jpg` (the deck page at 1280px and in a 360px frame), `row-menu-wide-light.jpg` (the open menu of a row with proxies of two finishes), `add-proxy-chooser-phone-light.jpg`, `add-proxy-form-phone-light.jpg`, `add-proxy-form-error-phone-light.jpg`, `add-proxy-form-wide-dark.jpg`, `change-proxy-phone-light.jpg`, `remove-proxy-phone-light.jpg` (the add, change and remove pages at 390px), `decks-page-wide-light.jpg`, `decks-page-phone-dark.jpg` (the Decks page with the Proxy column and the phone fold), `remove-deck-with-proxies-wide-light.jpg` (the confirmation naming the proxies), `import-preview-proxies-wide-light.jpg` (the preview's Proxies section). Every image was looked at; the supervisor re-read the deck page's wide light and phone dark shots. The captures start about 8px from the left edge and stop about 20px short of the right, as spec 066's do (the capture method, not the app).

## Implementation review

SPEC-ALIGNED, after two follow-up rounds; the last round's fixes were checked by the coordinator and not re-reviewed (the coordinator's ruling, 2026-11-11, option A).

`sdd-review` Mode B, read-only, on Opus, with a full `bin/ci` (4050 examples, 0 failures, 1 pending: the existing art-agreement example, which needs `COLLECTOR_ART_AGREEMENT`) before it.

- **Round 1** (HEAD `08b76a30` plus the screenshots): DRIFT DETECTED. One major: the add-a-proxy chooser's `main` lacked `c-decks`, so AC-9.1's touch floor and long-title wrap did not apply and no example used a 60-character deck name. Minor: the deck page's "Add a proxy" link was 40px on touch; coverage gaps on AC-1.10, 2.8, 2.12, 3.5, 4.1, 4.2, 4.3, 5.5, 6.4, 6.6, 7.2, 7.5, 7.8 and 8.2; six comment and copy nits (a wrong FR number, plan task ids in comments, an unformatted number in the add notice, an unscoped set filter, a stale example title). Fixed in `8fb8fdc7` (the chooser, the button, the long-name examples) and `d627cbe1` (the coverage examples, each mutation-checked, and the nits).
- **Round 2** (HEAD `d627cbe1`): DRIFT DETECTED, narrower. One major on AC-9.1: the chooser's Set select (40px) and the form's Finish select (36px) are below 44px on a coarse pointer. Minor: the format-change refusal examples created the expected winner last and had no language tie; AC-2.12 did not cover bulk mode and the scanner; AC-3.5 did not assert that nothing else changed. Nit: a vacuous assertion. The earlier fixes, the new examples, the CSS rule's heading, the set-select scope and the deviations (the touch floor at every pointer for buttons; AC-4.3's refresh simulated by `update!(retired_at:)`) were judged acceptable. Fixed in `0b7c8112`: a coarse-pointer rule for `.c-decks` selects (it also lifts the Change format page's select; an app-wide select floor is out of scope, and a possible follow-up issue), an example that reads the rule because headless Firefox can't emulate a coarse pointer, and the three minor examples and the nit. Not re-reviewed.
- **Not PASS before round 2's fixes:** AC-9.1 (selects), AC-2.12, AC-3.5, AC-6.4: each now has the example named in `0b7c8112`; the supervisor checked the diff against the findings.


## Distilled

2026-11-11, before the merge (`distill-feature`): the area docs `collection-and-lots.md`, `data-portability.md` and `tenancy-and-accounts.md` carry the feature's rules (written with the feature, T23, each statement with its source), `CLAUDE.md`'s deck sentence and its two spec lists point at them, the design system's `DeckPage`, `DecksIndex`, `ProxyTag` and `AddProxy` carry the markup, the spec's index row reads Frozen with its plan "retirement owed", and the spec has its `Frozen` line. The Distillation log rows say "spec 068's pull request (#313)". After the merge the plan is retired as `distill-feature` state 1 says.
