# Verification: Spec 041, Move Many Lots at Once

**Spec:** [spec.md](spec.md) 0.4.0 · **Plan:** [plan.md](plan.md) · **Pull request:** (number when opened; closes [#48](https://github.com/plainprogrammer/Collector/issues/48))

## Evidence per criterion

Spec files: `spec/models/lot/bulk_move_spec.rb` (the move), `spec/models/bulk_selection_spec.rb` ("#after_move!"), `spec/requests/bulk_move_spec.rb`, `spec/routing/routes_spec.rb`, `spec/import_apply_core_spec.rb`, `spec/system/bulk_move_spec.rb`, `spec/requests/bulk_move_timing_spec.rb`. Below, "model" is `spec/models/lot/bulk_move_spec.rb` and "request" is `spec/requests/bulk_move_spec.rb`; the example names are as written in the files.

| Criterion | Evidence |
|---|---|
| AC-1.1 bar and menu order | request:33 "offers Move to… after Set condition and before Remove, in the bar and in the menu"; system:39 (menu at 360px) |
| AC-1.2 no location | request:43 "when the account has no location", example at :46 |
| AC-1.3 ticks recorded, page opens | request:60 "records the ticks and opens the move page, keeping the page" |
| AC-1.4 nothing selected | request:71 "refuses with the bulk table when nothing is selected" |
| AC-1.5 all gone | request:79 "refuses when the ticked lot was removed in another tab"; :88 "…every ticked lot is another account's" |
| AC-1.6 GET with no selection | request:141 "sends the collector back to the bulk table when nothing is selected" |
| AC-1.7 last location removed | request:154 "answers 'You have no locations yet.' with a selection and no location"; :382 refusal (2) |
| AC-2.1 heading, To options, own place left out | request:98 "says how many items, offers a required To select…"; :116; :122 "leaves out the selection's own place" |
| AC-2.2 no destination | request:407 refusal (4); system:26 "does not move when the To prompt is left" |
| AC-2.3 foreign or removed location, 404 | request:426 refusal (5) |
| AC-2.4 Back and Cancel | request:98; :417 refusal (4) "keeps Back and Cancel…" |
| AC-3.1 same lots, same ids, notice | model:13; request:183 "moves the three lots with the same ids and says how many items"; :209; system:11 |
| AC-3.2 to no location | model:26; request:193 |
| AC-3.3 merge into the destination's lot | model:76; request:201 |
| AC-3.4 selected lots of one identity merge | model:84, :94 "lets the sort choose the survivor" |
| AC-3.5 merge with the destination's lot too | model:102 "folds two moved lots into the destination's lot…" |
| AC-3.6 already there, counted | model:49, :60; request:215, :223, :229 |
| AC-3.12 selected lot already there is the target | model:110; request:235 |
| AC-3.7 every lot already there | model:65; request:438, :446 refusals (6) |
| AC-3.8 cap | model:141, :149, :155, :162 ("the 9,999 cap"); request:453 |
| AC-3.9 selection under all locations | `bulk_selection_spec.rb` "#after_move! (spec 041)" (:184); request:268, :280; system:11 |
| AC-3.13 restart under a location filter | `bulk_selection_spec.rb` :184; request:291, :301 |
| AC-3.10 only one identity merges | model:32 |
| AC-3.11 removal Undo unaffected | request:256 |
| AC-4.1 every matching lot, exceptions | request:314 |
| AC-4.2 filter shows what is left, nearest page | request:314, :326 "lands on the nearest real page…" |
| AC-4.3 name filter and No location | request:336 |
| AC-4.4 5,000 lots in under 2 s | `spec/requests/bulk_move_timing_spec.rb:22` (see Measured); model:202 "statement counts" |
| AC-5.1 foreign lot ids ignored | model:187 "touches only the account's lots"; request:88, :461 |
| AC-5.2 foreign location 404 | request:426 |
| AC-5.3 no account, user or admin value | request:461 |
| AC-5.4 prefetch changes nothing | request:165 |
| AC-6.1 without scripting | request:495 "moves the lots with plain forms…" |
| AC-6.2 phone width | system:39 "reaches Move to… from the bar's menu at 360px and fits the move page" |
| FR-1 the action | as AC-1.1 to AC-1.6, AC-4.1, AC-5.4; `spec/routing/routes_spec.rb:72` "routes Move to…" |
| FR-2 the move (merge, cap, key rule, one transaction, tenant) | model, including :39 "keeps each moved lot's key equal to the one Lot.key_for gives" (the parity), :169 (foreign-key rollback), :187 (tenant) |
| FR-3 the answers | request "moving" (:182), "refusals" (:348), "a stale page submitted twice" (:472) |
| FR-4 the core names no collectible | `spec/import_apply_core_spec.rb` |
| NFR Performance | model:205 "runs as many statements for 12 lots that merge with nothing as for 2"; request:171 "runs the same queries for 1 and 30 selected lots and for 1 and 30 locations"; the timing example |
| NFR Accessibility | markup asserted in request:98; the keyboard flow and screen reader are Manual checks |
| NFR Security | as AC-5.1 to AC-5.3 |
| NFR Reliability | model:141 to :169; request:472 |
| Error Scenarios | request:246 (a selected lot removed in another tab), :353 to :401 (the order of answers), :472 (stale twice), and the examples above |
| Decision 7 (no export change) | no file of `docs/export-format/` or the Coverage tables changes; the suite's coverage guard stays green |
| Documents that change | Manual checks, last row |

## Measured

| What | Command | Result |
|---|---|---|
| AC-4.4, Performance: 5,000 lots, 300 locations, every matching lot to one place | `SCANNER_TIMING=1 bin/rspec --tag timing spec/requests/bulk_move_timing_spec.rb` | 615 ms, 2,018 statements; 5,396 lots before, 2,000 after (every copy kept) |
| Move page queries, 1 and 30 selected lots, 1 and 30 locations | `bin/rspec spec/requests/bulk_move_spec.rb -e "same queries"` | Equal counts (the example asserts it) |

## Manual checks

| Check | Result |
|---|---|
| Accessibility NFR: the whole flow with the keyboard alone (Edit many, tick or Select all, Tab to "Move to…", Enter, choose in To, Move; also Cancel; the status region announces the notice and each refusal; the To error is read with its field; focus is visible throughout), and with a screen reader | In part. Automated: `spec/system/bulk_move_spec.rb` "moves a ticked lot with the keyboard alone…" ticks a row with Space, presses "Move to…" with Enter, reaches To with Tab, chooses Blue binder by type-ahead (arrow keys don't change a closed select under WebDriver) and submits with Enter; the lot moves and the notice shows. It sends keys to the checkbox, "Move to…" and "Move" directly, so it doesn't prove they are in tab order, and it doesn't check visible focus. **Owed to the maintainer, by hand:** the Tab order of the row checkbox and the bar's buttons, visible focus throughout, and a screen-reader pass (the status region, the To field's error). Whether this is before merge or deferred is the maintainer's call. |
| Phone width: the bar's menu reaches "Move to…"; the move page fits (the system example proves 360px; this is a look at a real phone or 390px window) | Looked at 390px in a headless Firefox frame, light and dark ([`screenshots/`](screenshots/): `phone-bulk-menu-*`, `phone-move-page-*`): the menu lists Set condition…, Move to…, Remove; the move page fits. **Owed to the maintainer:** a look on a real phone. |
| Documents read: area doc, `BulkForm.md`, `Form.md`, `CLAUDE.md`, `docs/roadmap.md` agree with the code | Read against the code on 2026-11-06 (controller): they agree; one citation fixed (the foreign location's 404 is AC-2.3 and AC-5.2, not AC-5.1; f80588e). |

## Rulings during execution

- Task 11's refusal examples passed on arrival: the refusal code was written with Task 10's create under Task 10's failing examples; Task 11's examples pin it (controller ruling).

## Screenshots

Taken on 2026-11-06 with headless Firefox (Selenium) from a temporary system example (deleted, not committed) on factory data: one collector, three locations ("Blue binder", "Long box", "Red deck box") and six placeholder printings (no card art). Desktop at 1280px, phone at 390px in a fixed-width frame; light and dark. Each image was inspected; the files are in [`screenshots/`](screenshots/).

## Implementation review

SPEC-ALIGNED (round 2; 0 blocking, 0 major, 0 minor open).

- **Round 1** (Opus, read-only, `sdd-review` Mode B): GAPS FOUND, 0 blocking, 1 major, 5 minor. The code matched every AC, FR, NFR and Error Scenario. Major: the manual checks were all Pending. Minors: the area doc's Sources line left out supersessions of specs 032 and 037; no request example for a destination removed between the lookup and the write (the `rescue_from(InvalidForeignKey)`); AC-4.2's empty-location sentence not asserted; no example for a scanner entry after a merge; no example under a condition sort (plan risk 3).
- **Fixes:** 17a6163 (Sources), f30b9d1 (the 404 after the lookup; AC-4.2's sentence), d5e8ec4 (scanner entry; condition sort for the survivor and the cap refusal), 24ac631 (a keyboard-only system example), f80588e (an area-doc citation found reading the documents). Each new example was checked by breaking the code it pins.
- **Round 2:** SPEC-ALIGNED. Every minor closed; the major settled by the keyboard example, the documents read and the 390px screenshots, with the hand checks above owed to the maintainer. The reviewer noted that the condition-sort survivor example shows the sort runs inside the move rather than that it orders survivors (lots of one identity share a condition, so the lower id decides either way).

## Distillation

On 2026-11-06, before the merge: [`collection-and-lots.md`](../../architecture/collection-and-lots.md) carries the whole spec (written in plan Task 17 and the review fixes; Distillation log row in ef9e87e). The index row reads Frozen, by collection and lots, with the plan's retirement owed; the spec's frozen line is cd84c64. No other area doc changes: data portability needs nothing (decision 7), and the design-system docs `BulkForm.md` and `Form.md` were updated in Task 16. The plan is retired after the merge.
