# Verification: Spec 070, Replace a Proxy with a Copy (#257)

Spec v0.4.1 (Approved at Gate A; 0.4.1 is a one-sentence patch when `main` moved), plan revision 3 (Approved at Gate B). Branch `070-replace-proxy-with-copy`.

## Acceptance criteria and the examples that prove them

Request specs are `spec/requests/…`, model specs `spec/models/…`, system specs `spec/system/…` (headless Firefox unless said).

| AC | Proved by |
|----|-----------|
| AC-1.1, AC-1.3 | `deck_pages_spec.rb`, "has a menu cell with the proxy items for a row with a proxy, and none for a row without" (the four items with their hrefs, danger last, no `form`; the row with no proxy has no trigger) |
| AC-1.2 | `deck_pages_spec.rb`, "names the finish in a row with proxies of two finishes" (eight items in the spec's order, each href to its own proxy) |
| AC-1.4 | `deck_pages_spec.rb`, "leaves the two replacement items out for a proxy whose printing's collectible the instance no longer registers, and keeps them for a registered printing in a deck of an unregistered type"; `deck_proxy_replacements_spec.rb` and `deck_proxy_copies_spec.rb` (404 for such a proxy) |
| AC-1.5 | `deck_pages_spec.rb`, the statement-count example (1 proxy row against 6 rows, two with two finishes); mutation-checked (`replaceable?` running a query fails it) |
| AC-2.1 to AC-2.6 | `deck_proxy_replacements_spec.rb`, "the page": detail page, heading, muted line, fields at 0 with `min`/`max`, the lot label, groups and order (newest printing first, a retired printing listed), only free lots (no zone, Considering, another card, another deck's zone, another account), the zone-named place, "1 proxy" and a 60-character place, the empty state with the Back button and no form |
| AC-2.7 | `deck_proxy_replacements_spec.rb`, equal statement counts for 1 lot and 200 lots of 20 printings in 2 places; the first run found 13 against 15 (the request's query cache hid statements when both lots shared the proxy's printing), fixed in the fixture, and the `preload(:location)` mutation now fails it (14 against 35) |
| AC-2.8, AC-2.9 | `deck_proxy_replacement_tenancy_spec.rb` (another account's deck and proxy, this deck with another account's proxy, a sibling deck's proxy, a place's id, a zone's id, `"<id>abc"`, signed out; the owner's own 200 is the control); `deck_proxy_replacements_spec.rb` (404 for an unregistered printing's type) |
| AC-3.1 to AC-3.3 | `deck_proxy_replacements_spec.rb`, "Use these copies": the notice, the proxy lowered with the same id and a later `updated_at`, removed at the whole count, another printing's copies in a row of their own with the card's Total unchanged; `use_copies_spec.rb`, `move_into_zone_spec.rb` |
| AC-3.4 | `move_into_zone_spec.rb` ("keeping its id", the lot key `Lot.key_for` with the zone's id) and the request example's `condition` and finish kept |
| AC-3.5, AC-3.6 | `deck_proxy_replacements_spec.rb` and `use_copies_spec.rb`: "Enter a number from 0 to M." under the lot (`3`, `-1`, `1.5`, `abc`), "Enter a number from 1 to N." under the fieldset (blank, over the count), the sum's sentence only when no field or lot sentence applies |
| AC-3.7, AC-3.8 | `move_into_zone_spec.rb` (the second move over the cap rolls the first back) and the request example (nothing written, "One lot can hold at most 9,999 copies." under the lot) |
| AC-3.9 | `use_copies_spec.rb` (four examples, one fixture per cause: removed, taken into a zone, moved out in part, another account's; a missing or malformed `shown` fails closed; a lot with 0 is ignored) and the request example (the refused page writes `shown` again and the next submit succeeds; mutation: dropping the shown check fails it) |
| AC-3.10 | `deck_proxy_replacements_spec.rb` ("judges a proxy lowered since the page was shown against its count now"; a removed proxy is 404) |
| AC-3.11 | `use_copies_spec.rb` and `deck_proxy_replacements_spec.rb`, "moves once when the same form is submitted twice" (lot of 5, 2 entered: the second submit is refused as changed) |
| AC-3.12 | `deck_proxy_replacements_spec.rb`, "agrees across the deck page, the card page's Your copies, the collection and the Decks page" |
| AC-3.13 | `deck_proxy_replacements_spec.rb`, "ignores an account id, a zone id and a location id in the request" |
| AC-3.14 | `use_copies_spec.rb` (a lot the vocabulary can no longer save: its sentence beside a total over the count, and not the sum's) and `move_into_zone_spec.rb` (`:not_saveable` told apart from `:cap`) |
| AC-3.15 | `use_copies_spec.rb`, "builds the page of a refusal from a fresh read after the rollback": a **characterisation that passes on arrival** (the lots are re-read after the transaction anyway; per-line mutation testing found the `@free_lots = nil` resets unobservable, kept as the spec requires) |
| AC-4.1 | `deck_proxy_copies_spec.rb`, "the page": Quantity 1 with `max` the count, the Finish chosen, Condition, Price paid, the read-only Location (`p.c-field__label + p.c-field__value`), no location select, the hidden `shown_quantity`, "Add copy", Cancel to the deck |
| AC-4.2 to AC-4.5 | `deck_proxy_copies_spec.rb`, "adding the copy" and `add_copy_spec.rb`: the lot in the zone (merged by `Lot.add!`), the proxy lowered or removed, "replacing 3 proxies" / "1 proxy", the proxy in the path lowered whatever the copy's finish, Add a copy's own sentences, the over-count sentence after them, the cap |
| AC-4.6, AC-4.6a | `deck_proxy_copies_spec.rb` and `add_copy_spec.rb`: a count that is not the shown one is refused with "This proxy changed…", the form shows the count now and the next submit works; a removed proxy is 404 |
| AC-4.7, AC-4.8 | `deck_proxy_copies_spec.rb` (an account, location, zone id and entry key are ignored), `deck_proxy_replacement_tenancy_spec.rb` (every 404 on both pages and both verbs; signed out) |
| AC-4.9 | `deck_proxy_copies_spec.rb`, "the card page's own form and Edit copy are unchanged"; `lots_spec.rb`, `lot_moves_spec.rb` green |
| AC-5.1 | `lot_proxy_isolation_spec.rb` (now also walks `Lot::MoveIntoZone`) and `deck_proxy_replacements_spec.rb` ("changes no proxy when a copy reaches the zone by any other path") |
| AC-5.2 | `deck_proxy_replacements_spec.rb`, "leaves the other proxies, other decks and the other account's lots as they were" |
| AC-5.3 | `deck_proxy_replacements_spec.rb` (the export after a replacement: the lowered proxy, the moved lots, no new key) and `deck_proxy_replacement_round_trip_spec.rb` (exported and applied on a fresh account: the same collection and the same deck counts) |
| AC-5.4 | spec 068's "a catalog refresh changes no proxy" example still passes; no code of this spec touches the refresh |
| AC-6.1 | `deck_proxy_replacements_spec.rb` (system): both pages and both refused pages (submitted inside the narrow frame) at 360, 640 and 1280px in both themes with 60-character deck, place and card names, no horizontal overflow, each error read by its field's `aria-describedby` |
| AC-6.2 | `deck_proxy_replacements_spec.rb` (system), two examples: the rules read from the stylesheets (`.c-pick__lot .c-input` and `.c-decks .c-btn` as plain rules, the coarse-pointer `.c-btn, .c-input` of components.css, `.c-field select` of spec 072, which replaced spec 068's `.c-decks` select rule), `c-decks` on both pages' `main`, and the buttons and number fields measured as drawn (a lower bound: headless Firefox has a fine pointer) |
| AC-6.3 | `deck_proxy_replacements_spec.rb` (system), "shows the focus ring on a focused number field's wrapper and on the Finish select" |
| AC-6.4 | read: `UseMyCopy.md`, `AddProxy.md` (new "Add a new copy" section), `DeckPage.md`, the README, the previews `UseMyCopy`, `AddNewCopy` and their phone pairs |
| AC-6.5 | read: one CSS rule, `.c-decks .c-field__value`, in `additions.css` under its own heading; `spec/design_system_files_spec.rb` green |
| AC-7.1 | `deck_core_spec.rb` (the count is 54: 48 plus the six files) and `import_apply_core_spec.rb` (`lot/move_into_zone.rb` is in its list; proved able to fail by a temporary `# scryfall` comment) |
| AC-7.2 | read: the comments of `Lot.free`, `Lot::MoveIntoZone`, `UseCopies`, `AddCopy`; `bin/ci checks` ratchet (see the run below) |
| AC-7.3 | the grep below |
| AC-7.4 | read: `collection-and-lots.md`, `tenancy-and-accounts.md`, `CLAUDE.md`, `docs/roadmap.md` |

## The grep for the supersession list (AC-7.3)

`git grep -n -i "use my copy\|add a new copy\|UseMyCopy\|#257\|writers\|only by hand\|changes a proxy\|Change proxy count\|Remove proxy" -- spec docs CLAUDE.md app ':!.kamal/secrets'`. Each hit and what became of it:

- `spec/requests/deck_pages_spec.rb` (the two menu examples): changed (T6).
- `spec/requests/deck_proxies_spec.rb:254,256` (the Change page's "To remove it, use Remove proxy."), `spec/system/design_system_deck_components_spec.rb:201,289,298` (static drawings): unaffected.
- `app/helpers/decks_helper.rb` (`proxy_item_label`'s comment): replaced (T6). `app/assets/stylesheets/collector/additions.css:520,523,584`: still true.
- `app/models/deck/proxy.rb` header and `spec/models/lot_proxy_isolation_spec.rb` header: updated.
- `docs/architecture/collection-and-lots.md`, `tenancy-and-accounts.md`, `CLAUDE.md`, `docs/roadmap.md`: updated (T15).
- `docs/design-system/components/UseMyCopy.md`, `AddProxy.md`, `DeckPage.md`, the README, the previews `UseMyCopy`, `UseMyCopyPhone`: updated (T14); `DeckPage.html` and `DeckPagePhone.html` already listed the four items in order; they still draw "Move copies" on rows with no proxy, a leftover of spec 060 that spec 068's "empty cell" rule made stale (not this spec's; noted for the maintainer).
- Frozen specs (060, 064, 066, 068, the issue design): not edited; the supersessions are recorded in spec 070 and `docs/specs/README.md`.

## Deviations from the plan, and findings during execution

- T4's "refuses a lot that was removed, taken into a zone, moved out in part, or is another account's" example was one example in the plan; mutation testing showed it could not tell the four causes apart, so it is four examples (one fixture per cause).
- T7's AC-2.7 example failed on a fixture artefact (the request's query cache), not an N+1; the fixture was changed (the 1-lot case uses a different printing) and the code was not.
- T10's `"12abc"` fixture could not fail (no proxy had that id); it is now `"<proxy id>abc"`.
- T12's no-script example: `rack_test` treats a closed `details` as hiding its links and cannot open one, so the example asserts the row's `details > summary` exists and clicks the link with `visible: :all` (a browser without script opens the `details` natively); the driver is asserted and `driven_by` is declared before the sign-in.
- Several specs use `def` helpers instead of `let` for RuboCop's `RSpec/MultipleMemoizedHelpers`; no assertion was changed.
- Two T2 examples ("joins a caller's transaction", "leaves a failure of an outer transaction rolled back as a whole") cannot tell plain participation from a savepoint (both roll back with the outer transaction); the contract is stated in the class comment (found by mutating `Lot.transaction` to `requires_new: true`).
- Spec 071 reuses `Lot.free` and `Lot::MoveIntoZone` by cherry-picking commits `6fc4b8c9` and `22ed55b3`, which this spec froze after sending them to the coordinator.

## Evidence

Screenshots and GIFs are in `screenshots/` (factory data, placeholder card images); each was looked at before it was committed and no defect was found in the new pages. Wide shots are the 1280px window, phone shots a 360px frame; names read `<state>-<wide|phone>-<light|dark>`.

- Row menu: `deck-page-row-menu-wide-light`, `deck-page-row-menu-phone-dark`.
- Use my copy: `use-my-copy-{wide-light,wide-dark,phone-light,phone-dark}`, `use-my-copy-long-names-{phone-light,wide-dark}` (60-character place and deck names), `use-my-copy-refused-sum-{wide-light,phone-dark}`, `use-my-copy-refused-field-{phone-light,wide-dark}`, `use-my-copy-refused-changed-wide-light`, `use-my-copy-refused-cap-phone-light`, `use-my-copy-empty-{wide-light,phone-dark}`.
- Add a new copy: `add-new-copy-{wide-light,wide-dark,phone-light,phone-dark}`, `add-new-copy-refused-count-{wide-light,phone-dark}`, `add-new-copy-refused-changed-wide-light`, `add-new-copy-long-names-phone-light`.
- The deck page after: `deck-page-after-use-wide-light` (proxy lowered, owned row), `deck-page-after-add-phone-light` (proxy gone).
- GIFs: `use-my-copy-wide-light.gif`, `add-new-copy-wide-light.gif`, `use-my-copy-phone-light.gif`.
- Seen while capturing, both existing behaviour of the deck page and not this spec's: at 360px the last items of a row's menu near the bottom of the viewport sit behind the fixed tab bar until the page is scrolled, and a short card name can break mid-word in the narrow Card column.

## Implementation review

SPEC-ALIGNED

`sdd-review` Mode B, read-only, on `opus`, against `origin/main...HEAD` at the merge of `origin/main` (`bfaec02b`): no blocking or major finding; ten minor findings, taken as follows. One round; the fixes are small and each is pinned by an example that was seen to fail (or a mutation that makes it fail), so no second round was run.

| Finding | Disposition |
|---------|-------------|
| F1 the read-only Location label kept a paragraph's default margins (a larger gap in `add-new-copy-wide-light.jpg`) | Fixed in `1fcbb9ca`: the rule of `.c-decks .c-field__value` also resets `.c-decks .c-field > p.c-field__label`; a system example measures the margins (it read `12px` before the CSS); `AddProxy.md` and the README's App additions line updated |
| F2 "This proxy changed…" was hidden when the form had its own error, and the page then rewrote `shown_quantity` to the new count | Fixed in `015571de`, test first (model and request examples failed before): the changed check always runs after the form's own sentences (decision 10's order) |
| F3 `lot_pick_label` read `Current.account` without saying so | `9ebbe91a`: the comment says it |
| F4 the specs index row of 070 read Draft; 068's row lacked "AC-4.2 in part" | Fixed in the index |
| F5 the new routes' parameter written `:id` in the docs, `:proxy_id` in the route | Fixed in `UseMyCopy.md`, `AddProxy.md` and `collection-and-lots.md` (the older rows of spec 068 are left as written) |
| F6 AC-2.2's order inside a group was proved only by the newest printing | `60775f8b`: two examples assert the exact order of lots that differ by finish, condition, price paid and place; mutating the `ORDER BY` fails them |
| F7 AC-4.3 and AC-4.4 assertions were partial | `60775f8b`: exact sentences (the cap, the price, the condition, the finish), an unknown-condition case |
| F8 two Error Scenarios had no example (a retired proxy printing; a proxy with no finish on a printing that lists some) | `60775f8b`: a request example for each, both pages |
| F9 the `lower_by!` example's title promised `updated_at` | `60775f8b`: `updated_at` is made old first and asserted changed |
| F10 this file cited spec v0.4.0 | Fixed (v0.4.1) |

Strengths the review recorded: tenancy (every read through `Current.account`, no parameter names an account, zone, location or entry, another account's lot id is only ever "no longer free"), the transaction structure (`Lot::MoveIntoZone` joins the caller's transaction, the refusal propagates, the page is built after the rollback), the statement counts, the escaping in `lot_pick_label` and `replaces_line` (plain Strings through `safe_join`), and the frozen shared files (no blocking defect).
