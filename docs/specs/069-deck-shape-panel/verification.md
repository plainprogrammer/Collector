# Verification: Feature 069, The Deck Shape Panel

**Spec:** [spec.md](spec.md) (v0.2.2) · **Plan:** [plan.md](plan.md) (v1.2) · **Issue:** [#256](https://github.com/plainprogrammer/Collector/issues/256)

Each acceptance criterion with the spec example (or the document check) that proves it. A path is a spec file; a quoted name is the example's title or its `describe`. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`).

## Acceptance criteria

### Story 1: The deck page shows the shape panel

| AC | Proved by |
|---|---|
| AC-1.1 | `spec/requests/deck_shape_panel_spec.rb` "puts the details copy, the aside copy and the zones inside c-deck, in that order", "has the three parts in order in each copy" |
| AC-1.2 | same file, "gives no id twice, no root id, and labels the aside by its own title" |
| AC-1.3 | `spec/system/deck_shape_panel_spec.rb` "the page container's widths" (the fold, closed, in 360px and 640px frames; the aside, open, not sticky, above the zones in 768px and 1000px frames; the 320px sticky aside beside the zones at 1280px). Frames are chosen by the page container's width, not the frame's (see "Deviations", 2) |
| AC-1.4 | `spec/requests/deck_shape_panel_spec.rb` "draws no panel for a deck with neither a main nor a commander zone row", "…for a collectible whose vocabulary answers none", "…for a deck of a type no longer registered, and still answers 200"; `spec/models/catalog/deck_shape_spec.rb` (nil for an unregistered type, a vocabulary with no `deck_shape` and a nil answer); `spec/system/deck_page_spec.rb` "leaves the second column empty from 992px for a deck whose collectible draws no panel" (the second column stays empty) |
| AC-1.5 | `spec/requests/deck_shape_panel_spec.rb` "shows the empty states of a Casual deck with no card"; `spec/models/mtg/deck_shape_spec.rb` "says '1 card' and '0 cards' and delimits thousands", "is nil with no card in the curve…", "says '1 nonland card' and, for none, 'no cards'" |
| AC-1.6 | `spec/requests/deck_shape_panel_spec.rb` "is a 404 for another account's deck and shows none of its figures"; spec 066's own 404 examples in `spec/requests/deck_pages_spec.rb` stand |
| AC-1.7 | `spec/deck_core_spec.rb` (the seam is in its patterns, the frame partial under the `app/views/decks/**/*.erb` glob; 50 files; no game, format or zone but Considering in any, comments included) |
| AC-1.8 | `spec/requests/deck_shape_panel_spec.rb` "keeps the panel for a format the instance no longer registers" |

### Story 2: The mana curve

| AC | Proved by |
|---|---|
| AC-2.1 | `spec/models/mtg/deck_shape_spec.rb` "buckets Bolt, Elves, Counterspell and a Forest as AC-2.1 says" |
| AC-2.2, AC-2.3 | same file, "puts 0, 5, 6, 7, 9 and 1,000,000 in columns…", "floors a half value into the whole number below it…" |
| AC-2.4 | same file, `#average_text` ("is the exact mean, 2.625 shown 2.6", "keeps a trailing zero", "rounds 0.15 up with exact arithmetic…") |
| AC-2.5 | same file, "leaves a nonland card with no mana value out and counts it for the note", "words the note for several cards, and has none for a mana value of 0.0", "counts an entry with no MTG::Card row…"; `spec/requests/deck_shape_panel_spec.rb` "notes the nonland cards with no mana value after the average line" |
| AC-2.6, AC-2.7 | `spec/models/mtg/deck_shape_spec.rb` "leaves lands out and keeps Dryad Arbor in column 0", "uses the card's stored value for a double-faced and a reversible card…" |
| AC-2.8 | same file, `.build` ("counts Main only for a constructed deck…" with a mana value, a type and a colour in Sideboard and Considering that Main lacks, asserting the curve, the types, the scope and the symbols; "counts Commander and Main together…") |
| AC-2.9 | `spec/models/mtg/deck_shape_spec.rb` "texts"; `spec/requests/deck_shape_panel_spec.rb` "reads each chart for a screen reader once per copy and hides the columns" (the columns' `aria-hidden`; the labels row's `aria-hidden` is by reading `_parts.html.erb`), "draws a column with the proxy part above the owned part…" |
| AC-2.10 | `spec/requests/deck_shape_panel_spec.rb` (numbers only in `style`, the legend naming each series); `spec/system/deck_shape_panel_spec.rb` "draws owned solid ink-muted, proxy hatched, and the mana segments in their own tokens" in both themes (owned's fill, a hatched gradient on proxy and no `brand`; the hatch's `line-strong` lines and the outline are spec 060's CSS, proved by `spec/system/design_system_deck_components_spec.rb`) |

### Story 3: Counts by card type

| AC | Proved by |
|---|---|
| AC-3.1, AC-3.2, AC-3.3, AC-3.4 | `spec/models/mtg/deck_shape_spec.rb` `#types`; `spec/requests/deck_shape_panel_spec.rb` "lists the types with the proxy suffix, empty where a row has none…" |
| AC-3.5 | `spec/models/mtg/deck_shape_spec.rb` "skips a row of another collectible…" (a lot of another type placed in a zone, built with a factory; the hand-built fallback was not needed); `spec/requests/deck_shape_panel_spec.rb` "skips a card of another collectible in the panel and shows its row flat in the zone table" |

### Story 4: Coloured mana symbols

| AC | Proved by |
|---|---|
| AC-4.1 to AC-4.5, AC-4.7, AC-4.8, AC-4.10 | `spec/models/mtg/deck_shape_spec.rb` `#symbols` (including exact totals for `{3}{X}{C}{S}{G}` and `{HW}`, 1 of 8 is 13%, and Sideboard and Considering holding a green card Main lacks) |
| AC-4.6 | same file "marks a segment under 10% narrow and not one of exactly 10%"; `spec/requests/deck_shape_panel_spec.rb` "marks a segment under 10% of the symbols narrow in the page" |
| AC-4.9 | `spec/requests/deck_shape_panel_spec.rb` (the bar's `role="img"` label); `spec/models/mtg/deck_shape_spec.rb` "reads the symbols label for the scope"; `spec/system/deck_shape_panel_spec.rb` (each of the five segments in its `mana-*` fill and `on-mana-*` text in both themes) |

### Story 5: Width and themes

| AC | Proved by |
|---|---|
| AC-5.1 | `spec/system/deck_shape_panel_spec.rb` "has no horizontal overflow at 360, 640, 768 and 1280px in the light and the dark theme with every panel part full" (every type, five colours, a mana value of 1,000,000, a 60-character deck name, 1,234 proxies) |
| AC-5.2 | same file "opens and closes the fold from the keyboard with no script, its summary ending in Show" and the 360px fold example (closed, summary at least 44px high; the keyboard example runs in a 375px frame, a 360px viewport); the facts line is in `spec/requests/deck_shape_panel_spec.rb` |
| AC-5.3 | same file "fits the open fold's parts in the panel's interior at a real phone's 360px viewport, with nothing cut off and each count with room in its column": a 375px frame (a 360px viewport) (375px with a 15px scrollbar; the example measures the scrollbar and sizes the frame so the viewport is 360px, because the CI runner's is about 12px), interior 278px, no scroll, nothing past the padding edge, no text cut off, and each count's room in its column at least 0 (measured +0.28px); proved able to fail in a 360px frame (263px, room -1.85px). The spec's wording was patched to v0.2.2 for the 278px (see "Findings", 1). The "average line wraps" clause is by reading: the line is an ordinary paragraph in a narrow column and `screenshots/long-*` show it wrapped |
| AC-5.4 | Markup examples above (a count above every column, a letter and count in every segment, the caption, the legend); verified by reading `app/views/mtg/deck_shapes/_parts.html.erb` against the Charts rule |

### Story 6: What the page reads

| AC | Proved by |
|---|---|
| AC-6.1 | `spec/requests/query_counts_spec.rb` "keeps the deck page's queries the same with 40 printings, owned and proxied, as with one printing, panel included", "adds one statement for the panel, and none when Commander and Main hold no card" (broken once on purpose to see it fail); `spec/models/mtg/deck_shape_spec.rb` "runs one statement for the mana values however many cards, and none for an empty deck" |
| AC-6.2 | `spec/models/deck/page_spec.rb` unchanged and green (its 3 and 6 statements) |
| AC-6.3 | `spec/models/mtg/deck_shape_spec.rb` "reads the mana values once for the curve, the average and the note" |

### Story 7: The documents (verified by reading)

| AC | Checked |
|---|---|
| AC-7.1 | `docs/architecture/collection-and-lots.md`: the deck-page paragraph, the vocabulary-answers paragraph (the third answer), the new panel paragraph with decisions and the split-card limit named deliberate, the two stale statements ("both not built", "the shape panel (#256) and proxies (#254) are not"), three Named constants rows, Sources; `docs/architecture/catalog-core.md` line 180 ("Nothing reads the column yet") says the panel reads it. Each checked against the code. The stale-statement grep (`shape panel`, `#256`, `not built`, `first reader`) was run before and after |
| AC-7.2 | `docs/design-system/components/DeckShape.md` (the settled rules, the note, the empty sentences, the aria-label wording, the width note) and `DeckPage.md` ("As built", "a deck whose collectible draws no panel") |
| AC-7.3 | `docs/specs/README.md` has the 069 row and the pointer on 066's row (written with the spec); `CLAUDE.md`'s decks sentence and guard sentence name the panel and `Catalog::DeckShape`; `spec/deck_core_spec.rb` lists the seam and counts 50 |
| AC-7.4 | `bin/yard doc` builds with 0 warnings; the comment ratchet (`ruby script/yard/comment_ratchet.rb`) reported "28 added or changed public objects, all with a comment" |

## Supersession grep (spec 069 "Existing examples this changes")

`git grep -n -i "shape\|c-deck\|c-shapefold\|aside\|second column\|children.length" -- spec ':!.kamal/secrets'` was run when the plan was written and again in T7. Hits changed: `spec/requests/deck_pages_spec.rb` (the "no shape panel" example, retitled without the `be_nil` line) and `spec/system/deck_page_spec.rb` (the "second column empty" example, rewritten for a deck of another collectible under `:other_collecting`). Hits left alone, with the reason: `spec/deck_core_spec.rb` (count updated), `spec/system/design_system_deck_components_spec.rb` (builds its own markup), `.c-decks` on the Decks index, "File-shape checks" comments and scanner fixtures.

## Screenshots

In [`screenshots/`](screenshots/): factory data, placeholder card images. Each still in `-light` and `-dark`:
- `full-wide`, `full-phone-fold-closed`, `full-phone-fold-open` (a 375px frame, a 360px viewport), `full-phone390-fold-closed`, `full-phone390-fold-open`: a 72-card Modern deck with every type, mixed owned and proxy cards and a narrow white segment.
- `stacked-768`: the open aside above the zones.
- `commander-wide`: "Commander + Main · 100 cards".
- `empty-wide`, `empty-phone-fold-closed`, `empty-phone-fold-open`: the empty states.
- `no-mana-values-wide`, `no-mana-values-phone-fold-closed`, `no-mana-values-phone-fold-open`: the note under the curve.
- `proxies-only-wide`, `proxies-only-phone-fold-closed`, `proxies-only-phone-fold-open`: hatched columns only.
- `long-wide`, `long-phone360vp-fold-closed`, `long-phone360vp-fold-open` (375px frame), `long-phone345vp-fold-closed`, `long-phone345vp-fold-open` (360px frame, a 345px viewport): a 60-character deck name, an average of 1,000,000.0 and a 6+ column of 1,357.
- `deck-fills.gif` (desktop) and `deck-fills-phone.gif` (a 375px frame, the fold opened at the end): an empty deck, then 20 Lands, 24 spells owned and 8 proxies, the panel redrawn each time.

Every shot was looked at. What they show: the panel is correct in both themes; the fold and the aside swap at 640px of container as drawn; the white segment under 10% has no label and the caption carries it; the empty states read as specified. Defects found are listed under "Findings".

## Findings (recorded, not fixed here)

1. **The 360px browser frame is 15px tighter than a phone.** The test frame keeps a pinned 15px classic scrollbar (`spec/support/system.rb`, #271) and the page has an 8px body margin, so a 360px frame leaves a 263px panel interior where a real 360px phone leaves 278px (360 − 16 body − 32 page padding − 2 border − 32 panel padding). Spec 060 drew the panel for 279px. AC-5.3 is proved at a 375px frame (a 360px viewport) (375px with a 15px scrollbar; the example measures the scrollbar and sizes the frame so the viewport is 360px, because the CI runner's is about 12px): interior 278px, the 6+ column about 36.28px wide and its count "1,357" 36px wide, a margin of +0.28px. In the 360px frame the same count overflows its column by about 1.85px (and the panel's inner edge by about 1px), measured once and not committed. Only a four-digit 6+ count does this (a deck with 1,000+ cards in the 6+ column), and the CSS belongs to spec 060: no CSS was changed. For the maintainer to decide whether to widen the count's room (a CSS follow-up).
2. **Mana bar labels crowd at four-digit counts** (five roughly equal segments of "2,591": the label touches the segment borders; `screenshots/long-*`). Same cause and owner as 1.
3. **Card types row**: a proxy suffix wider than the 4.5rem minimum ("1,234 proxy") pushes that row's count about 7px left of the other rows' counts (`screenshots/long-*`). Spec 060's `c-types__proxy` minimum width; four-digit proxy counts only.
4. **The mana caption wraps in awkward places at narrow widths** (a line can begin with "· ", a colour name can split from its count: `screenshots/commander-wide-*`, `long-*`). The separators are plain text joined in `MTG::DeckShape#caption`; a non-breaking join would change the strings the specs assert, so it is left for the maintainer's call.
5. **An empty or valueless curve draws a blank 96px band above the baseline.** It follows spec 060's empty state ("seven columns of 0, no bars"); noted because it reads as white space.

## Deviations from the plan

1. T9's AC-5.3 example runs in a 375px frame at 278px, not a 360px frame at 279px (Findings, 1); the coordinator ruled "do not touch CSS" for any fit failure, and the implementation review found that the approved wording needed a spec update, so spec v0.2.2 (a PATCH, spec only) rewords AC-5.3 and records the known limit in its Error Scenarios.
2. T9's frame widths follow the page container, as the plan's review required (768px and 1000px for the aside, 360px and 640px for the fold). The container in a frame of W px is W minus 15 (scrollbar) minus the body's 16 minus the page padding, so the comments in the example use measured numbers (a 640px frame has a 545px container, and 640px of container needs a frame of at least 735px).
3. T9's paint example's script is a quoted heredoc (`<<~'JS'`), because Ruby turned `\b` in a regular expression into a backspace.
4. The spec's decision text for v0.2.0 reached the file only in v0.2.1 (a scripting slip, recorded in the spec's changelog); the coordinator confirmed the re-applied text matches what Gate A was shown.
5. `RSpec/SortMetadata` reordered the metadata of three examples (`:aggregate_failures, :other_collecting`).

## Implementation review

SPEC-ALIGNED WITH MINOR FINDINGS (round 2, `sdd-review` Mode B, read-only Opus review of `cdf7a475..HEAD` at spec v0.2.2)

- **Round 1** (the same review at spec v0.2.1): GAPS FOUND, one major (a process gap) and minors. The major: AC-5.3's approved wording ("279px inside it at 360px") could not be met as built, because a 360px phone viewport leaves 278px (the page's 8px body margin; spec 060's arithmetic left it out), so the example proved a different width than the spec said, and a deviation note was not enough. Resolved by spec v0.2.2 (a PATCH through `sdd-spec-update`: AC-5.3 reworded with the arithmetic, the known limit added to the Error Scenarios, changelog row; commit `d6f870a6`). The minors were fixed in `3890f529` (the AC-5.3 example now asserts each count has room in its column, `countRoom >= 0`, and was shown to fail in a 360px frame; the AC-3.4 example asserts the proxied land is not in the curve, shown to fail), `f1a96d08` (the average memoised; header comment), `d81398b7` (roadmap link) and this file's corrections of overstated claims.
- **Round 2** confirmed every round-1 finding resolved (reading the diff and the files), the scope clean (the one controller line and its comment; `Deck::Page`, the zone partial, the row menu, CSS, tokens, migrations and the export untouched; no shipped spec edited), the core guard (50 files, no core file naming a game, a format or a zone but Considering), and 38 of 39 spot-checked example titles in this file existing exactly once (the one mismatch, the AC-6.1 row's old title, and two nits (a comment saying 1px for 1.85px; the AC-5.2 row's frame) are corrected here and in the spec file).
- **Edge cases the reviewer checked, none a defect:** a zone with only proxies; a card in both Commander and Main (each row counts separately; the identity ids are de-duplicated for the one statement); `value.floor` on a float; the exact Rational mean; an identity with several card rows (the unique index); huge counts; another account's deck (a 404).
- **Open for the maintainer** (not defects of this spec): the CSS follow-ups in "Findings" above.

## Distillation (`distill-feature`, spec 027)

- `docs/architecture/collection-and-lots.md` (the panel's rules, the seam, the deck-page paragraph, the Named constants rows, Sources and the log row, written with T10 and distilled here) and `docs/architecture/catalog-core.md` (the mana value's first reader). The design system's `DeckShape.md` and `DeckPage.md` were updated in T10; the design system has no area doc or Distillation log.
- `docs/specs/README.md`: the 069 row is Frozen, by those two area docs, Plan "retirement owed"; the supersession of spec 066 AC-1.6 and AC-5.1 is in both directions (written with the spec). The Distillation log rows say "spec 069's pull request" until the pull request has a number; the plan's retirement follows the merge (state 1).
- `CLAUDE.md`: the decks sentence and the guard sentence name the panel and `Catalog::DeckShape` (a pointer, no rule restated).
- No ADR proposed: ADR 0028 and spec 066 decision 5 already set the seam pattern.
- The Issues bullet of `collection-and-lots.md` still lists #253 and #254 as open (stale before this spec; noted by T10 and left for the next distillation of those specs).
