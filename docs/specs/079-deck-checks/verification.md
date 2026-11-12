# Verification: Feature 079, Deck Checks

**Spec:** [spec.md](spec.md) (v0.2.1) · **Plan:** [plan.md](plan.md) (present, retirement owed after the merge) · **Issue:** [#258](https://github.com/plainprogrammer/Collector/issues/258)

Each acceptance criterion with the spec example (or the document check) that proves it. A path is a spec file; a quoted name is the example's title. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`). The feature's spec files were run together on 2026-11-12 (`bin/rspec spec/models/catalog/deck_checks_spec.rb spec/models/mtg/deck_rules_spec.rb spec/models/mtg/deck_checks_for_magic_spec.rb spec/requests/deck_checks_spec.rb spec/system/deck_checks_spec.rb spec/deck_core_spec.rb spec/models/deck/page_spec.rb`): 81 examples, 0 failures. `bin/ci` is T5.3's and is not recorded here.

Short names used below: **core** `spec/models/catalog/deck_checks_spec.rb`; **rules** `spec/models/mtg/deck_rules_spec.rb`; **magic** `spec/models/mtg/deck_checks_for_magic_spec.rb`; **request** `spec/requests/deck_checks_spec.rb`; **system** `spec/system/deck_checks_spec.rb`.

## Acceptance criteria

### Story 1: Check a deck on demand

| AC | Proved by |
|---|---|
| AC-1.1 | request "shows the button and no results on the plain deck page (AC-1.1, 1.9)" (the link, no heading, no form, no cache tag). "Runs the statements it ran before": `app/models/deck/page.rb`, `DecksController` and `spec/models/deck/page_spec.rb` are unchanged on the branch and the page spec is green; request "runs the plain deck page's statements however many rows the deck has" compares the check with the plain page, not the plain page with `main`'s, so the "before" half rests on the unchanged code |
| AC-1.2 | request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" (four results in decision 10's order; `main`'s children are `c-item__head`, `c-deckcheck`, `c-deck`) |
| AC-1.3 | request "shows no results on the next deck page request after the deck changes (AC-1.3)" (the proxy removed by its `DELETE`, the redirect followed, then the check again). The removal is the request the row menu's page sends, not a browser click |
| AC-1.4 | request "shows the same results again and every link of the plain page (AC-1.4, 1.5)" |
| AC-1.5 | same example (every `href` of the plain page's `main` present, no `disabled` or `aria-disabled`, Edit deck answers 200) |
| AC-1.6 | request "is a 404 for another account's deck, a zone and a bad id (AC-1.6)" (and the other deck's name absent from the body) |
| AC-1.7 | request "words no findings, one finding and several (AC-1.7)"; core "says the format has no rules and still runs owned-plus-proxy" ("1 finding") and "treats a missing method, a nil answer and an unregistered type alike (AC-5.5)" ("No findings") |
| AC-1.8 | request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" (the tag on the results page) and "shows the button and no results on the plain deck page (AC-1.1, 1.9)" (none on the plain page); system "asks for the check again on Back instead of restoring a Turbo snapshot (AC-1.8)" (the outcome) |
| AC-1.9 | request "shows the button and no results on the plain deck page (AC-1.1, 1.9)" and "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" (Check deck is an `a.c-btn--secondary`; `main form` is nil on both pages) |

### Story 2: Deck size

| AC | Proved by |
|---|---|
| AC-2.1 | magic "judges Main and Sideboard in each constructed format's own name" (Standard, 58: "Main: 58 cards; Standard needs at least 60."); request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)"; core "judges a minimum with the true count in every sentence" |
| AC-2.2 | magic "counts a proxy toward Main and passes at 60 and at 15" (60 passes, Standard); the 61 case: core "judges a minimum with the true count in every sentence" (a registered test format, not Magic's); request "words no findings, one finding and several (AC-1.7)" (60 Plains in Standard: "No findings") |
| AC-2.3 | magic "judges Main and Sideboard in each constructed format's own name" (Modern among the six, Sideboard 16: "Over"); 15 passes: magic "counts a proxy toward Main and passes at 60 and at 15" (Standard; Modern has the same rules object, rules "has size and copy rules for each constructed format"); none: request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" ("Pass Sideboard: 0 cards", Standard) and magic "names a Sideboard the deck has no zone row for from the registration (AC-2.12)". No example runs the 15 and 0 cases on a Modern deck itself |
| AC-2.4 | magic "judges Commander's two zones together" (99 Short, 101 Over) and "passes Commander at exactly 100 while cards in Considering count nowhere (AC-2.4, 2.5)" |
| AC-2.5 | magic "passes Commander at exactly 100 while cards in Considering count nowhere (AC-2.4, 2.5)"; core "counts nothing in Considering or an unnamed zone, and passes at exactly the exact size" |
| AC-2.6 | magic "counts a proxy toward Main and passes at 60 and at 15" (59 owned and 1 proxy); core "judges a minimum with the true count in every sentence" |
| AC-2.7 | magic "says Casual and an unregistered format have no rules but still flag a forgotten proxy"; request "gives a deck with no rules the no-rules line and the owned-plus-proxy result (AC-2.7)"; core "says the format has no rules and still runs owned-plus-proxy" |
| AC-2.8 | magic "judges Main and Sideboard in each constructed format's own name" (Pauper, Pioneer, Legacy and Vintage among the six, each sentence with its own format's name). The example's Main holds 58, not the AC's 59: the sentence and the name per format are proved, the number 59 is not |
| AC-2.9 | magic "leaves out another collectible's cards" ("Main: 0 cards; Standard needs at least 60."); system "asks for the check again on Back instead of restoring a Turbo snapshot (AC-1.8)" (an empty Standard deck reads "Main: 0 cards") |
| AC-2.10 | magic "leaves out another collectible's cards"; core "leaves out another collectible's cards and zones no rule names" |
| AC-2.11 | core "leaves out another collectible's cards and zones no rule names" (a `stash` zone's 7 cards in no size count) and "passes at the limit and counts no copy in an unnamed zone" (copies). No Magic-deck example builds a zone row whose key Magic's rules don't name |
| AC-2.12 | magic "names a Sideboard the deck has no zone row for from the registration (AC-2.12)"; core "names a rule's zones in its key order and a zone the deck lacks by its key" (the fallback to the key) |
| AC-2.13 | magic "judges Commander's two zones together" ("Commander + Main: …"); core "names a rule's zones in its key order and a zone the deck lacks by its key" |

### Story 3: Copy limits

| AC | Proved by |
|---|---|
| AC-3.1 | magic "adds a card's copies across printings, zones, owned and proxy" ("Lightning Bolt: 5 copies; the limit is 4."); core "names a card over its limit across zones, printings and owned plus proxy"; request "words no findings, one finding and several (AC-1.7)" (5 Shock in Main is a finding). No example asserts the sentence for 5 copies of one printing in Main alone |
| AC-3.2 | core "passes at the limit across two named zones (4 of 3 + 1)" (the passing half); magic "adds a card's copies across printings, zones, owned and proxy" (Main and Sideboard summed, Standard). The AC's Modern deck of 3 Main and 2 Sideboard is not built; Modern's copy rule is the same object (rules "has size and copy rules for each constructed format") |
| AC-3.3 | magic "adds a card's copies across printings, zones, owned and proxy" (two printings, owned and proxy: 5); core "names a card over its limit across zones, printings and owned plus proxy". Neither is a Legacy deck, and the "3 owned and 2 proxy of one printing" case is not built as such; owned plus proxy is summed in both examples |
| AC-3.4 | magic "exempts basic lands and any-number cards, and holds Commander to one of the rest" (20 Plains in Standard; 2 Snow-Covered Island in Commander); rules "is none for a basic land, Snow-Covered ones included" |
| AC-3.5 | magic "exempts basic lands and any-number cards, and holds Commander to one of the rest" (9 Relentless Rats); rules "is none for any-number text, in every format" |
| AC-3.6 | magic "exempts basic lands and any-number cards, and holds Commander to one of the rest" (Krenko in Commander and Main: "2 copies; the limit is 1."; two Snow-Covered Islands no finding) |
| AC-3.7 | magic "restricts a card to one in Vintage only" (Vintage "Black Lotus: 2 copies; restricted to 1."; Legacy passes at 2); rules "is 1, restricted, in Vintage only" (Legacy's limit is 4) and "is 4 in constructed formats and 1 in Commander" (an unrestricted card in Vintage is 4) |
| AC-3.8 | core "passes at the limit and counts no copy in an unnamed zone" (9 copies in Considering not counted) |
| AC-3.9 | core "orders findings by first zone, then name, then identity; leaves out another collectible" and "orders two findings of one zone by name, then by identity when the names match" |
| AC-3.10 | magic "exempts basic lands and any-number cards, and holds Commander to one of the rest" and "restricts a card to one in Vintage only" ("No card is over its limit."); request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" |
| AC-3.11 | magic "leaves out another collectible's cards" (70 copies of another collectible's card, "No card is over its limit."); core "orders findings by first zone, then name, then identity; leaves out another collectible" |
| AC-3.12 | magic "holds a numbered card to its number in every format, and passes at that number" (8 in Standard and in Commander: "the limit is 7"; 7 passes); rules "is the stated number for up-to text, in every format" |
| AC-3.13 | magic "names a card by its English name when its first row in page order is a Japanese printing" |
| AC-3.14 | Rule level: rules "is the ordinary limit for a printing with no card data, a basic land included" (4 in Standard, 1 in Commander, for a Plains with no record). End to end only for the mixed case: magic "counts a basic land's two printings, one with no card data, at the ordinary limit (AC-3.14, 3.16)". No example checks a deck with 5 copies of a record-less printing in Standard, or 2 record-less basic lands in Commander, through the report |
| AC-3.15 | No example asserts it as written. Core "names a card over its limit across zones, printings and owned plus proxy" and magic "adds a card's copies across printings, zones, owned and proxy" show copies of one card in Main and Sideboard summed into one sentence, but they use `include`, so neither proves there is exactly one finding, and neither uses 5 + 5 |
| AC-3.16 | magic "counts a basic land's two printings, one with no card data, at the ordinary limit (AC-3.14, 3.16)"; core "treats nil as above every number: unlimited only when every printing says nil" |

### Story 4: A card with owned copies and proxies in one zone

| AC | Proved by |
|---|---|
| AC-4.1 | core "flags a zone that holds both, across printings, naming the split"; magic "says Casual and an unregistered format have no rules but still flag a forgotten proxy"; request "shows no results on the next deck page request after the deck changes (AC-1.3)" |
| AC-4.2 | core "flags a zone that holds both, across printings, naming the split" (owned of one entry, proxy of another of the same identity) |
| AC-4.3 | core "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible" and "judges each zone alone, includes zones no rule names, and skips Considering's lone proxy" |
| AC-4.4 | core "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible" |
| AC-4.5 | magic "says Casual and an unregistered format have no rules but still flag a forgotten proxy" (Casual's finding; for the unregistered format the example asserts the no-rules line only); request "gives a deck with no rules the no-rules line and the owned-plus-proxy result (AC-2.7)"; core "says the format has no rules and still runs owned-plus-proxy" (a type and format the instance doesn't register: the finding is shown) |
| AC-4.6 | core "judges each zone alone, includes zones no rule names, and skips Considering's lone proxy" (findings in Main and in another zone, each with its split). Main and Sideboard by name are not built |
| AC-4.7 | core "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible"; request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" |
| AC-4.8 | request "changes nothing: no write reaches lots, proxies or locations (AC-4.8)" |
| AC-4.9 | core "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible" (another collectible's owned copy and proxy in one zone, not flagged). Built with stubbed entries, not a Magic deck |
| AC-4.10 | core "judges each zone alone, includes zones no rule names, and skips Considering's lone proxy" ("Lightning Bolt in Stash: 2 owned, 3 proxy.") |

### Story 5: What the checks read, and what they change

| AC | Proved by |
|---|---|
| AC-5.1 | request "runs the plain deck page's statements however many rows the deck has" (5 and 500 rows; 13 statements each; mutation proof 2). `Deck::Page#zones` as before: `app/models/deck/page.rb` and `spec/models/deck/page_spec.rb` unchanged on the branch, the page spec green |
| AC-5.2 | request "redirects a visitor who is not signed in (AC-5.2)" |
| AC-5.3 | Evidence below ("Export, import and backup unchanged") |
| AC-5.4 | `spec/deck_core_spec.rb` (green): `app/models/catalog/deck_checks.rb` added as a pattern, the controller and `_check` under the existing globs, the count raised by 3 to 68; `app/models/mtg/deck_rules.rb` sits outside the core |
| AC-5.5 | core "treats a missing method, a nil answer and an unregistered type alike (AC-5.5)" |

### Story 6: The results are readable

| AC | Proved by |
|---|---|
| AC-6.1 | system "fits a phone, in both themes, with a long card name (AC-6.1, 6.4)" (a 360px viewport frame: no sideways scroll, no clipped status, sentence or head button; mutation proofs 3 and 6) |
| AC-6.2 | system "says pass or fault in words with an icon on every row, never by colour alone (AC-6.2)" (mutation proof 6); request "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)" (each row's text starts with its word) |
| AC-6.3 | system "moves keyboard focus to the results heading (AC-6.3)" (Tab reaches Check deck, Enter, the heading has focus; mutation proof 5) and "puts the results before the zones in reading order (AC-6.3)" |
| AC-6.4 | system "fits a phone, in both themes, with a long card name (AC-6.1, 6.4)" and "wraps a long zone name inside the results at phone width, in both themes (AC-6.4)" (mutation proof 3). The zone-name example measures the results section only (Deviations, c) |

### Story 7: The documents (verified by reading)

| AC | Checked |
|---|---|
| AC-7.1 | `docs/architecture/collection-and-lots.md` (commit `32b86d92`): the Check deck paragraph, the seam paragraph pointing to `Catalog::DeckChecks`' comment for the contract, the bullets (what is counted, owned plus proxy, Magic's rules, the order), the words table, the paragraph saying spec 069's non-goal "deck rules" is done in part; the head's actions, the fourth vocabulary answer, the deck guard's count (54 corrected to 68, 071's and 073's files were missing), the statement-count invariant, four Named constants rows, a decision, the accepted-limits lines, Sources and the issues list. Each statement carries its spec 079 decision or AC. Grepped before for "deck rules", "no rules", "Check deck", "Non-Goal": no statement had been made stale but the guard's count |
| AC-7.2 | `docs/specs/README.md` row 079 (written with the spec): names collection and lots and `DeckPage.md`, "Nothing: it does the 'deck rules' that 069 left as a non-goal" |
| AC-7.3 | Comments read: `Catalog::DeckChecks` (the contract in its header, `@param`/`@return` on `.report`), `MTG::DeckRules` (`.for`, `.limit_for`), `MTG::Collecting.deck_rules`, `Decks::ChecksController`. `bin/yard doc --no-cache` builds with 0 warnings (run 2026-11-12 after T5.1). The comment ratchet runs in T5.3's `bin/ci`; it was not run here |
| AC-7.4 | `docs/design-system/components/DeckPage.md` ("Spec 079 (#258) adds 'Check deck'…": the link, the `DeckCheck` section between head and `c-deck`, still no `form`, the no-cache tag) and the new `DeckCheck.md` |
| AC-7.5 | `docs/roadmap.md` theme C, item 14n: #258 "Built 2026-11-12, done when its pull request merges", as the theme's other built items are marked before their merge |
| AC-7.6 | `CLAUDE.md` Project Status: "A collector checks a deck on demand from its page, … (`Catalog::DeckChecks`, `MTG::Collecting.deck_rules`, `Decks::ChecksController`, spec 079)"; and the collection-and-lots guard sentence names the `Catalog::DeckChecks` seam. No rule of the area doc restated |

**ACs without a full proof, said plainly:** AC-3.15 has no example that proves one finding of 10 copies. AC-3.14's two record-less cases are proved at the rule level and through the mixed case, not as decks of 5 and of 2 copies. AC-2.8 is proved with a 58-card Main, not 59. AC-2.3, AC-3.2 and AC-3.3 are proved on Standard decks or test formats, not on the Modern and Legacy decks their wording names (the six constructed formats share one rules object). AC-2.11, AC-4.6 and AC-4.9 are proved through the core with stubbed zones, not on a Magic deck.

## Supersession grep

The spec supersedes nothing. `git grep -n -i "deck rules\|copy limit\|deck size" -- spec docs app ':!.kamal/secrets'`, run after T5.1:

- Changed (this branch, all new text): `app/models/catalog/deck_checks.rb:1`, `app/models/mtg/collecting.rb:72`, `app/models/mtg/deck_rules.rb:1`; `docs/architecture/collection-and-lots.md` (the deck checks paragraph, the decision, the issues line, Sources); `docs/roadmap.md:50` (14n); spec 079's own `spec.md` and `plan.md`.
- Left, because they are records of shipped specs or name something else: `docs/specs/060-deck-components/spec.md:49`, `066…/spec.md:245`, `068…/spec.md:318`, `069…/spec.md:43` and `:276` (non-goals and futures that point to #258; shipped specs are not edited, `.claude/rules/documentation.md`; the area doc and the index record that 079 does them in part); spec 057's title, its frozen line, its `verification.md`, specs 060's and 062's "Depends on", `docs/specs/README.md:75`, roadmap 14a, `docs/architecture/README.md:21`, the distillation log rows in `catalog-core.md:229` and `collection-and-lots.md`, the issues design `:108` and `spec/system/design_system_deck_rules_spec.rb` ("deck rules" there is spec 057's design rules, not this feature); `docs/specs/076-select-label-gap/verification.md:32` (a record of a run); the issues design `:180` (the source of this spec); `docs/specs/README.md:97` (079's own row).

## Export, import and backup unchanged (AC-5.3)

Run 2026-11-12 on `32b86d92`:

- `bin/rspec spec/models/collection_export_spec.rb spec/backup_guards_spec.rb`: 58 examples, 0 failures.
- The export-format specs (`ls spec | grep -i export`: `collection_export_core_spec.rb`, `export_format_document_spec.rb`, `export_format_examples_spec.rb`, and `spec/models/export_format/`): `bin/rspec spec/collection_export_core_spec.rb spec/export_format_document_spec.rb spec/export_format_examples_spec.rb spec/models/export_format`: 120 examples, 0 failures.
- `CollectionExport::FORMAT_VERSION` is still `4` (`app/models/collection_export.rb:12`).
- `git diff main --stat -- db` prints nothing (no migration, no schema change).
- `git diff main --stat` over `app/models/collection_export*`, `app/models/collection_import*`, `app/models/export_format`, `lib/collector/backup*` and `docs/export-format` prints nothing.

## Scryfall facts

Plan T0.2, checked 2026-11-12 with curl against api.scryfall.com (User-Agent `Collector-dev`, Accept `application/json`):

- `cards/named?exact=Relentless+Rats` → type_line "Creature — Rat"; oracle_text:
  `'This creature gets +1/+1 for each other creature on the battlefield named Relentless Rats.\nA deck can have any number of cards named Relentless Rats.'`
- `cards/named?exact=Seven+Dwarves` → "Creature — Dwarf"; oracle_text:
  `'This creature gets +1/+1 for each other creature named Seven Dwarves you control.\nA deck can have up to seven cards named Seven Dwarves.'`
- `cards/named?exact=Nazg%C3%BBl` → "Creature — Wraith Knight"; oracle_text:
  `'Deathtouch\nWhen this creature enters, the Ring tempts you.\nWhenever the Ring tempts you, put a +1/+1 counter on each Wraith you control.\nA deck can have up to nine cards named Nazgûl.'`
- Japanese printings of Lightning Bolt (`q=lang:ja name:"Lightning Bolt" -name:"//"`, unique=prints): sets msc, tle, fca each `name` "Lightning Bolt", `printed_name` "稲妻", `lang` "ja", the same `oracle_id` 4457ed35-7c10-48c8-9776-456485fdf070; set sld has `printed_name` null.
- Consequence: `MTG::DeckRules::ANY_NUMBER` (`/a deck can have any number of cards named/i`) and `STATED_NUMBER` (`/a deck can have up to (\w+) cards named/i`) match the real wording; `Catalog::Entry#name` (Scryfall `name`) is the English name for a non-English printing (decision 6 holds).

## Mutation proofs

Each was made by hand, run, and reverted before its commit.

1. `MTG::DeckRules::MAIN_MINIMUM` 60 → 61 failed 3 examples of magic (lines 23, 32, 138): "judges Main and Sideboard in each constructed format's own name", "counts a proxy toward Main and passes at 60 and at 15", "leaves out another collectible's cards".
2. A per-card `Catalog::Entry.find` inside `split_lines` failed request "runs the plain deck page's statements however many rows the deck has": small check vs plain 18 vs 13, big 513 vs 13, big vs small 513 vs 18. Unmutated, the check and the plain page each run 13 statements for the 5-row and the 500-row deck; the example runs in 0.64–0.71 s.
3. Removing `overflow-wrap:anywhere` from `.c-deckcheck__row` failed system "fits a phone, in both themes, with a long card name (AC-6.1, 6.4)" (got `[false, 1]`) and "wraps a long zone name inside the results at phone width, in both themes (AC-6.4)" (got `[1, false]`).
4. Removing the `turbo-cache-control` line failed system "asks for the check again on Back instead of restoring a Turbo snapshot (AC-1.8)" (the stale "Main: 0 cards").
5. Removing `autofocus` failed system "moves keyboard focus to the results heading (AC-6.3)". Turbo focuses the heading on a link visit, so the plan's Stimulus fallback was not needed.
6. Breaking the markup (every `c-deckcheck__` class renamed `c-deckcheckX__`) showed two examples passing vacuously: "says pass or fault in words with an icon on every row, never by colour alone (AC-6.2)" passed, and so did the clipped-text part of the card-name phone example. Commit `62e1bc82` added existence assertions; both then failed against the broken markup (`spec/system/deck_checks_spec.rb:44` and `:72`).

**Characterisations** (examples that passed on arrival, because the behaviour was already built):

- T2.2's 13 magic examples (`eb7156f4`). Proof of failing: mutation 1 fails 3 of them. The other 10 have no recorded mutation of their own.
- T3.2's statement-count example (`81c5cf96`). Proof: mutation 2.
- T4.2's system examples (`d0acb71d`): focus (mutation 5), Back (mutation 4), status words (mutation 6, after `62e1bc82`), the phone-width examples (mutations 3 and 6). The reading-order example ("puts the results before the zones in reading order (AC-6.3)") has no recorded mutation proof.

## Screenshots

In [`screenshots/`](screenshots/). Environment: headless Firefox, factory data with placeholder printings and no card art; desktop in a 1400px window, phone in a 360px viewport frame, the phone JPEGs cropped to 360px to drop Firefox's 15px classic scrollbar. Twelve JPEGs (six pairs, `-light` and `-dark`) and one GIF; the brief named 13 JPEGs, the folder holds 12.

- `01-results-desktop-{light,dark}.jpg`: a Standard deck (Izzet Tempo) checked at desktop width: "4 findings", Short (Main 58), Over (Sideboard 16), Over the limit (Lightning Bolt 5), Owned and proxy (Shock in Main), above the zones and beside the shape panel; the heading's focus ring is visible.
- `02-results-phone-{light,dark}.jpg`: the same check at 360px: the three head actions on one line, the results in one column, the shape fold and the zones below.
- `03-vintage-restricted-desktop-{light,dark}.jpg`: a Vintage deck: Main and Sideboard pass, "Black Lotus: 2 copies; restricted to 1.", owned plus proxy passes.
- `04-commander-short-phone-{light,dark}.jpg`: a Commander deck at 360px: "Commander + Main: 92 cards; Commander needs exactly 100.", "Sol Ring: 2 copies; the limit is 1.", owned plus proxy passes.
- `05-casual-no-rules-phone-{light,dark}.jpg`: a Casual deck at 360px: "Casual has no rules to check." as a plain row, then "Llanowar Elves in Main: 3 owned, 1 proxy."
- `06-plain-page-head-phone-{light,dark}.jpg`: the plain deck page at 360px: Edit deck, Check deck and "…" fit one line; no results section.
- `07-walkthrough.gif`: a desktop walkthrough that starts on the plain Izzet Tempo page. Only its first frame was inspected for this record.

## Findings (recorded, not fixed here)

1. The focus ring on the "Deck check" heading spans the full content width on a direct visit (the heading is a block) and sits close to the text (shot 01); a mouse click on Check deck shows no ring (the browser's behaviour for script focus after a click). Cosmetic, left.
2. Shot 05: the owned-plus-proxy sentence wraps at 360px leaving "proxy." alone on its last line. Cosmetic.
3. A zone name of 60 unbroken characters overflows the zone head and the shape fold on the plain deck page. Pre-existing, and no registered format has such a name (zone names are copied from the registration); recorded in the area doc's accepted limits.
4. Unverified claims: Scryfall's wording is verified (above); Turbo's autofocus is proved by example (mutation 5); Firefox's bfcache under WebDriver is untested (the Back example proves Turbo's snapshot path only).
5. The 500-row statement-count example is not tagged `:timing`, so it runs in every suite (about 0.7 s).

## Deviations from the plan

a. T1.1's example "orders findings by zone, then name, then identity" expected a list without the no-rules line although it registers no rules; commit `b2ee0f10` expects `drop(1)` of the lines (a plan bug; the behaviour is as specified).
b. The component's classes were renamed from the plan's `c-check` to `c-deckcheck` (`4ca7014d`): `c-check` is `Form`'s existing checkbox-row class (5 views). Batch D's first version scoped the rule `.c-deckpage > .c-check` (`8d2fba5a`), replaced by the rename. The plan's text (T3.1's partial, T4.1's CSS, T4.2's specs) still shows `c-check`; the commits are the truth.
c. Batch D had added a second CSS block making zone heads and the shape fold wrap a 60-character zone name; it was dropped (`452cc148`) because it changed existing components outside the feature for a name no registered format has. AC-6.4's zone-name proof now measures the results section only, so such a zone name on the plain page still overflows (Findings, 3).
d. The vacuous-example fix (`62e1bc82`, mutation proof 6).
e. T4.3's screenshots came from a throwaway system spec rather than a dev server (the repo's recipe), deleted before the commit (`ec3260d4`).

## Commits

`git log --oneline c3589b30..HEAD` at this record's commit (newest first; this record's own commit follows):

```
32b86d92 docs(decks): document the deck checks in the area doc, CLAUDE.md and the roadmap (#258)
ec3260d4 docs(decks): screenshots and walkthrough for the deck checks (#258)
62e1bc82 test(decks): make the browser examples fail when their selectors match nothing (#258)
452cc148 fix(design): leave zone heads alone; test the results section's own width (#258)
4ca7014d fix(design): rename the DeckCheck classes to c-deckcheck, off Form's c-check (#258)
d0acb71d test(decks): the check's focus, Back and phone width in the browser (#258)
8d2fba5a feat(design): the DeckCheck pattern for the check results (#258)
81c5cf96 test(decks): the check runs no statement of its own (#258)
4c5097e6 feat(decks): Check deck on the deck page (#258)
eb7156f4 test(decks): Magic deck checks end to end through the seam (#258)
7988bb6d feat(decks): Magic's deck rules for the deck checks (#258)
afd799f3 feat(decks): copy-limit results for the deck checks (#258)
5362d866 feat(decks): size results for the deck checks (#258)
b2ee0f10 feat(decks): add Catalog::DeckChecks and its owned-plus-proxy check (#258)
```
