# Verification: Add to a Deck from the Card Page (spec 071, #255)

Plan: [plan.md](plan.md) (approved at Gate B). Spec: [spec.md](spec.md) v0.5.1.

## How each acceptance criterion is proved

`bin/rspec` examples, named by file; "system" examples run in headless Firefox (a fine pointer: the coarse-pointer sizes are measured with every `(pointer: coarse)` rule of the loaded stylesheets applied, `spec/support/coarse_pointer.rb`).

| AC | Proved by |
|----|-----------|
| 1.1 | `spec/requests/catalog/entries_show_spec.rb` "the Add to deck action": secondary link before Add a copy, the page's href with the collection mark, the icon, the menu still there |
| 1.2 | `spec/requests/catalog/visitors_spec.rb` (the absent selector `a[href*='/deck_additions/new']` and the string "Add to deck" in the lists; "sends a visitor's request for the Add to deck page to sign in": GET and POST redirect, no query against `lots`); `spec/system/visitor_catalog_spec.rb`; `spec/requests/deck_additions_spec.rb` "when signed out" |
| 1.3 | `spec/requests/catalog/entries_show_spec.rb` "is absent for a retired printing and a token" (with the live card as the positive control); `spec/requests/deck_additions_spec.rb` "is 404, on the page and on the create, for a retired printing, a token, a type with a vocabulary and no source, an unregistered type and an unknown key"; `spec/models/catalog/entry_spec.rb` `#deck_addable?` |
| 1.4 | `entries_show_spec.rb` "leaves the stats strip and the sections as they are, so #50's places are free" (the single Owned stat, no "Free to use", no "In decks") |
| 1.5 | `spec/system/card_page_spec.rb` "keeps the head's controls on one line at 360px / 390px with and without the … menu, also with the coarse pointer's sizes": one line, every control inside the row, the primary not clipped, no overflow, every control 44px with the coarse rules applied. This needed a change of the head's rule (deviation 1) |
| 2.1 to 2.4 | `deck_additions_spec.rb` "the page": title, heading, back link and Cancel with the collection mark, the select (Decks group only, no Places, no No location, other-type decks absent), the empty state with a link and no form, How many (required, no `max`, 1) |
| 2.5 to 2.8 | "What to use": the sentence and its place order, nothing chosen, all required; copies in a zone, proxies, another account's copies and another card's are not counted (with the owner's own copies as the positive control); one finish and none free chosen; two radios when copies are free; `spec/helpers/deck_additions_helper_spec.rb` (the sentence, five places then "and N more", the singular, delimiters); `spec/models/lot/free_copies_spec.rb` |
| 2.9 | `deck_additions_spec.rb` "runs the same number of statements for one lot and deck as for forty lots and ten decks"; `entries_show_spec.rb` "runs the same number of statements with the link as without it"; `free_copies_spec.rb` (three statements, not growing) |
| 3.1 to 3.5 | `spec/models/deck/addition_spec.rb` (split, whole lots with ids and fields kept, take order, merge into the zone's lot, the cap with the first move rolled back) and `deck_additions_spec.rb` "My copies" (notice, redirect with the mark, count over the free copies with the typed values kept, the cap sentence); mutation checks in `verification` below |
| 3.6 | `deck_additions_spec.rb` "says copies for more than one, and shows them as Deck › Zone in Your copies": Considering, Owned unchanged |
| 3.7 | `free_copies_spec.rb` and `addition_spec.rb` (shown printing first, newer printings next, within a printing in Your copies order); the sentence's places follow the same order |
| 3.8, 3.9 | `addition_spec.rb` "judges the count at the write" and "says so when nothing is free any more"; `deck_additions_spec.rb` "doesn't make the double submit lose or create copies" |
| 3.10 | `addition_spec.rb` "changes no proxy, deck, location, other card's lot or other account's rows" (no write to `deck_proxies`, `locations` or `decks`; the take happened as the positive control) |
| 3.11, 3.12 | `addition_spec.rb` (a lot whose finish or condition the vocabulary no longer knows, taken second of three: the sentence, nothing moved; a removed zone: `RecordNotFound`); `deck_additions_spec.rb` "answers 404 and moves nothing when the zone was removed" |
| 4.1 to 4.5 | `addition_spec.rb` "#save with a proxy" and `deck_additions_spec.rb` "a proxy" and "a proxy's refusals": merge keeps the id, the notice, the cap sentence, the finish sentences, the quantity sentence with the typed value kept, the deck page's dashed tag, the card page's Owned unchanged |
| 4.6 | `Deck::Proxy.add!`'s retry is spec 068's (`spec/models/deck/proxy_spec.rb`, AC-1.9); this feature calls it unchanged |
| 5.1 to 5.4 | `addition_spec.rb` and `deck_additions_spec.rb` "refusals and tenancy": 422 with the sentence on the field; 404 for another account's zone, a place, a deck's own location id, a missing zone and a bad id (the name built at run time, the owner's own request as the positive control); the ignored parameters; signed out |
| 5.5 | `spec/system/deck_additions_spec.rb` "without scripting": one example per use, `driven_by :rack_test` before the sign-in, the driver asserted, the whole path from the card page to the deck page |
| 6.1 | `deck_additions_spec.rb` "fits at 360, 640 and 1280px in both themes with 60-character deck, place and card names" and "wraps the refusal sentence that names a 60-character card at 360px" (found by the screenshot review: deviation 2) |
| 6.2 | `deck_additions_spec.rb` "shows the 2px focus ring on the radio row" |
| 6.3, 6.4 | `deck_additions_spec.rb` "the 44px floor": every coarse rule applied with the new rule required by selector, then the drawn heights of the select, the How many field, each radio row and both buttons are at least 44px, with the fine-pointer partner showing the radio rows are under 44px without the rule; and "keeps the new rule under its own heading, scoped to the pick list, with no colour or font literal" |
| 6.5 | `deck_additions_spec.rb` "ties each sentence to its field, with no inline style and one primary action" (and no empty `aria-describedby` on a valid page) |

### Mutation checks (examples that could not fail)

The request examples of the writes were integration examples over code a model spec had proved test-first, so they were green on their first run. Each describe was shown able to fail by breaking one line and restoring it: the redirect status (`:see_other` to `:found`), the collection mark on the redirect, the count taken (`fresh.take(1)`), the zone lookup's `raise`, and the notice's two branches. Each turned at least one example red (3 to 6 examples for the last three).

## Supersession list, from a grep

`git grep -n 'Add a copy\|Add to deck\|c-item__actions\|AddToDeck\|A proxy of\|My copies\|Free to use\|up to two options\|#255\|deck_additions' -- spec docs app CLAUDE.md ':!.kamal/secrets'`, run at the start of execution. Every hit that changed:

| Hit | Disposition |
|-----|-------------|
| `spec/system/card_page_spec.rb` phone example (`widths[2] > widths[0] / 2`, `> 200`) | Replaced by the one-line checks of AC-1.5; the example is renamed "shows a back link and the head's actions on one line on a phone" |
| `spec/requests/catalog/visitors_spec.rb` absent selectors and strings; `spec/system/visitor_catalog_spec.rb` | Gain the Add to deck selector and text |
| `docs/design-system/components/VisitorHeader.md` | Gains "Add to deck" |
| `docs/design-system/components/AddToDeck.md` and both previews | Per-finish proxy radios, the refusals drawn, the label's case, `c-decks` on `main`, the floors |
| `spec/system/design_system_deck_components_spec.rb` `use_choices` | One proxy radio per finish; one new example |
| `ItemPage.md`, `ItemPagePhone.md` and their previews | The head actions, the phone rule |
| `collection-and-lots.md` card-page section, glossary, constants, decisions, open-issues line (#255 built, the stale "proxies are not" clause fixed), sources; `tenancy-and-accounts.md`; `CLAUDE.md`; `docs/specs/README.md` rows 060 and 071 | Updated (T10) |
| `spec/system/design_system_deck_components_spec.rb:926` (a lower-case "… foil" in a drawn option) | Left as is: its example checks fit only |
| `docs/roadmap.md` item 14j | Marked by the distillation step at merge |

## Deviations

1. **The head row needed a CSS change (AC-1.5, allowed by the criterion).** At 360px the card page's three head controls need 318 to 326px against a 297px row in the narrow frame (15px classic scrollbar; 312px on a real phone). Below 640px of the page container the "Add to deck" link (class `c-item__adddeck`) hides its icon and the row's gap is 4px (`var(--space-1)`), scoped by `:has(> .c-item__adddeck)` so the deck page's head (same `.c-item__actions` rules) is untouched. Measured after the change at 360px and 390px, with and without the menu, fine and coarse: every control inside the row, one line, heights 38px fine and 46px coarse. `spec/system/deck_page_spec.rb` still passes unchanged.
2. **The screenshot review found a defect the examples missed:** the cap refusal sentence with a 60-character card name overflowed at 360px. Fixed test-first (`.c-decks .c-field__error { overflow-wrap:anywhere }`, two examples); it also lets other deck pages' sentences wrap.
3. **Flat `params.permit` instead of `params.expect`** (spec 0.5.0, decision 2): `expect` answers 400 for the radio a browser omits when none is chosen, where AC-5.1 wants a 422.
4. **The coarse-pointer examples apply every coarse rule** (spec 072's lesson) instead of reading one rule, and measure drawn heights; spec 072 (merged to main during this work) replaced the `.c-decks` select rule with an app-wide one, and spec 0.5.1 names it in AC-6.3.
5. `Catalog::Entry#deck_addable?`, `Location::Choices#decks_of` and `Lot::FreeCopies` are this spec's own; `Lot.free` and `Lot::MoveIntoZone` are spec 070's commits, cherry-picked unchanged.

## Not done, and open items

- #50's "Free to use" and "In decks" (the strip and the section) are not built: the action sits in the head and takes no room from them (AC-1.4).
- The "…" menu absent case at 360px: covered (a link whose host no source vouches for).
- Factory printings have no legality data, so the deck page's shots show "Not legal" in every format; nothing in this feature reads legality.
- Console output of the browser was not read (headless Selenium can't in this setup).

## Screenshots and walkthroughs

[`screenshots/`](screenshots/): 50 JPEGs and 3 GIFs from factory data and placeholder card images, light and dark, 1280px desktop and a 390px phone frame (360px where marked). `01` the card page head; `02` the page with free copies (My copies and a proxy radio per finish); `03` no free copy and one finish (the proxy chosen); `04` the empty state; `05` to `08` the refusals (nothing chosen, count over the free copies, the cap, a lot that can't be moved); `09` the 60-character worst case; `10` the refused cap with the long name (after the fix); `11` the card page after a move; `12` the deck page showing the card. GIFs: `add-to-deck-my-copies-desktop.gif`, `add-to-deck-proxy-desktop.gif`, `add-to-deck-my-copies-phone.gif`. Every image was looked at; the one defect is deviation 2.

## Implementation review

(written by the review)
