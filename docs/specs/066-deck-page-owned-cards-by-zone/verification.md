# Verification: Spec 066, The Deck Page, Owned Cards by Zone

**Spec:** [spec.md](spec.md) v0.3.1 · **Plan:** plan (retired in `bb52f62c6c7f377a1c72c76d1722f73237ea85d2`; read it with `git show bb52f62c6c7f377a1c72c76d1722f73237ea85d2^:docs/specs/066-deck-page-owned-cards-by-zone/plan.md`) · **Issue:** [#253](https://github.com/plainprogrammer/Collector/issues/253)

## Implementation review

SPEC-ALIGNED WITH FINDINGS

Mode B review by a read-only Opus subagent over `git diff` of the branch (2026-11-11, before the merge of `main`). No blocking finding; one major and nine minor. Dispositions:

| Finding | Disposition |
|---|---|
| M1: a 60-character deck name with no space overflowed the page head at 360px (AC-5.5, AC-5.6) | Fixed, test first (`5bb1c9c0`): the system example failed on `scrollWidth`, then `main` took `c-deckpage` and two rules in `additions.css` (`min-width:0`, `overflow-wrap:anywhere`) fixed it; `DeckPage.md` says so |
| 1: unused `names` helper in `page_spec` | Deleted (`0fbdaeb6`) |
| 2: no `verification.md` | This file |
| 3: the digits-only id guard is on `DecksController` only; `Decks::RemovalsController` and `Decks::FormatsController` still read `"12abc"` as 12 | Not changed: it stays scoped to the account (no tenancy hole) and the coordinator accepted the guard for `set_deck` only (Gate B note 1). The tenancy doc says which controller has it. Owed to the maintainer, see below |
| 4: proofs checking less than their criterion (AC-5.3 set line, AC-5.5 counts at every width, AC-3.6 at every width, AC-6.6 no face data, an unregistered collectible type) | Added (`0fbdaeb6`, `54f5e7d4`). Writing the AC-6.6 request example found a real defect the review had only hinted at: `MTG::Collecting.deck_card` showed a marker for a printing with no face data (the model example used Casual, which never has a marker). Fixed test first (`54f5e7d4`) |
| 5: stale comments in `additions.css` | Reworded (`2fd0b10f`) |
| 6: "until #253" wording in the specs index, `DecksIndex.md` and the area doc | Reworded (`065804d2`) |
| 7: `LEGALITY_FORMATS` written by hand | Kept: a spec pins it to `FORMATS` less Casual (AC-6.5) |
| 8: "5 statements" is "at most 5" | Reworded in `Deck::Page`'s comment and the area doc |
| 9: the `printing(...)` spec helper is defined three times | Kept: each file's helper differs in what it varies; not worth a shared helper |

The fixes were proved by the targeted runs below; a second review round was not run (the findings were local, and each fix has a failing-first example).

## Acceptance criteria and their proofs

| AC | Proof |
|---|---|
| 1.1, 1.3, 1.4, 1.6 | `spec/requests/deck_pages_spec.rb` ("the page and its head") |
| 1.2 | `deck_pages_spec` ("tenancy": another account's deck, a place's id, a zone's id, `0`, `abc`, `<id>abc`, an id nothing has, signed out) and `spec/requests/decks_spec.rb` ("followed by letters", the guard) |
| 1.5 | `spec/requests/decks_spec.rb` (the link examples) |
| 2.1, 2.2 | `deck_pages_spec` ("zones") and `spec/models/deck/page_spec.rb`. AC-2.1's "a zone the format does not list" shares the `|| keys.size` branch the unregistered-format example runs; `Location#zone_key_is_the_formats` refuses to build such a zone for a registered format, so no example can create one |
| 2.3 to 2.9 | `deck_pages_spec` and `page_spec` (finishes summed, printings split, other zone, a place, another account, retired printing, empty zone, shown name) |
| 2.10 | `page_spec` ("statements": `Deck::Page#zones` runs 5 for a small and a large deck alike; the controller adds 2) and `spec/requests/query_counts_spec.rb` (the whole request, small equal to large) |
| 3.1 to 3.5 | `deck_pages_spec` ("the legality marker"), `spec/models/mtg/collecting_deck_card_spec.rb`, `spec/system/deck_page_spec.rb` (muted ink in both themes) |
| 3.6 | `deck_pages_spec` (markup, twice) and `deck_page_spec` (exactly one marker displayed at 360, 640, 768 and 1280px) |
| 3.7 | `deck_pages_spec` (WebMock blocks every real request, so a fetch would raise) |
| 4.1, 4.2 | `deck_pages_spec` ("copies are not added or moved here") |
| 5.1, 5.2 | `deck_page_spec` (second column empty at 1280px; Cost, Owned, Proxy and Total share a left edge and width in three zone tables) |
| 5.3 | `deck_page_spec` (360px: Card, Cost and Total shown, set line and marker under the name, the beside-the-name copies hidden; 1280px the reverse) |
| 5.4, 5.5 | `deck_page_spec` (no horizontal overflow and a six-symbol cost inside its cell at 360, 640, 768 and 1280px, light and dark; zone counts uncut at every width; a 60-character deck name at 360px, both themes) |
| 5.6 | `deck_page_spec` (head actions below the name at 360px, at least 36px high; see the reading below) |
| 5.7 | `deck_pages_spec` ("each group in its own tbody under a rowgroup header") |
| 6.1, 6.6 | `spec/models/catalog/deck_cards_spec.rb`, `deck_pages_spec` ("a collectible that answers nothing", no extension record, no face data, an unregistered collectible type) |
| 6.2 | `spec/deck_core_spec.rb` (33 files: 26 before spec 066, 1 for spec 067, 6 for this spec) |
| 6.3 | `spec/models/mtg/deck_groups_spec.rb`, `collecting_deck_card_spec` |
| 6.4 | `deck_pages_spec` ("cost": first face, not the second; a muted dash for none) |
| 6.5 | `collecting_deck_card_spec` |

**Reading of AC-5.6 (v0.3.1).** The design system gives the 44px floor to coarse pointers (`components.css`'s `@media (pointer: coarse)`), and a fine-pointer Firefox measures the buttons at 38px at 360px. The example asserts 36px or more, which is what the criterion says for a fine pointer; the coarse rule is the design system's and is not re-proved here.

**At a 640px frame the table's container is 545px** (the page's padding), so the narrow layout applies there and the five-column layout is first proved at 768px; this matches spec 060 decision 9.

## Runs

- Targeted, on the merged tree (`98b340a1`): `bin/rspec spec/models/catalog spec/models/mtg spec/models/deck spec/requests/deck_pages_spec.rb spec/requests/decks_spec.rb spec/requests/query_counts_spec.rb spec/deck_core_spec.rb spec/system/deck_page_spec.rb spec/system/decks_spec.rb`: 878 examples, 0 failures.
- New example counts: `deck_cards_spec` 6, `deck_groups_spec` 17, `collecting_deck_card_spec` 13, `entry_display_name_sql_spec` 1, `page_spec` 12, `deck_pages_spec` 32, `deck_page_spec` (system) 24, plus the `decks_spec` link and guard examples.
- CI: recorded in the pull request.

## Documents verified by reading

`DeckPage.md` (as-built paragraph, the row-menu note, the head's wrapping), `DecksIndex.md` (the name is a link), `collection-and-lots.md` (the deck page, the seam, the two named constants, the zone-order note, Sources), `tenancy-and-accounts.md` (the route, the digits-only guard, Sources), `CLAUDE.md` (the deck sentence, the spec list, the guard sentence), `docs/specs/README.md` (the 066 row; the supersession recorded in the 060 and 062 rows). The distillation logs are written by the distillation step.

## Distillation

Distilled into [collection and lots](../../architecture/collection-and-lots.md) (the deck page, the seam, the constants, the zone-order note) and [tenancy and accounts](../../architecture/tenancy-and-accounts.md) (the route's 404 rule); the architecture README lists spec 066 under both; each area doc has a Distillation log row reading "spec 066's pull request" until the pull request is numbered. The design system's `DeckPage.md` and `DecksIndex.md` were updated in the feature's own commits. CLAUDE.md's deck sentence, spec list and guard sentence point to the area docs. The index row is Frozen with its plan "retirement owed"; the frozen line is on the spec. No ADR was proposed: the seam is one more optional answer on ADR 0028's.

Not done here (not this branch's): spec 067's plan, whose pull request has merged, is owed a retirement; that is a housekeeping branch from `origin/main`.

## Screenshots

`screenshots/deck-page-wide-light.jpg`, `-wide-dark.jpg` (1280px) and `-phone-light.jpg`, `-phone-dark.jpg` (360px, in a narrow frame), from a throwaway system spec with a Modern deck of three zones: Creatures, Instants, Sorceries and Lands groups (an Artifact Land inside Lands), a banned and a not legal marker in the muted ink, a 60-character name with no space and a six-symbol cost, and an empty right column. No horizontal overflow at either width (`scrollWidth` 15px under `innerWidth`, the classic scrollbar).

## Owed to the maintainer

- The digits-only id guard is on `DecksController` only (Gate B note 1). `Decks::RemovalsController`, `Decks::FormatsController` and `Decks::SelectionsController` still read `"12abc"` as 12, within the account. A follow-up could share one lookup.
- On a phone each zone's Cost column sizes itself (spec 060 decision 9's auto layout), so Cost's left edge differs a little between zone tables below 640px; it is fixed from 640px.
