# Implementation Plan: Design System: Deck Components and Previews

**Spec:** [docs/specs/060-deck-components/spec.md](spec.md) (version 1.0.2: Approved at Gate A on 2026-11-10; 1.0.1 and 1.0.2 are the patches the plan review forced, see its changelog)
**Decisions:** none new; the maintainer's rulings are the spec's decisions 1–17, 23 and 24, and decisions 18–22 and 25 were confirmed at Gate A. No ADR (decision 18).
**Issue:** [#249](https://github.com/plainprogrammer/Collector/issues/249) (roadmap item 14b)
**Created:** 2026-11-10
**Status:** Draft (plan review rounds 1 and 2 fixed; awaiting Gate B)
**Review:** round 1 (read-only Opus): NEEDS REVISION, 0 blocking, 6 major, 6 minor, 2 nits; fixed in this draft: the blocks go at the end of the file (cascade), the host page is stripped, a pip is 22px (spec 1.0.1: Cost 11rem), the head's line check, the types' counts line up, AC-3.11 reads right edges in the narrow layout, controls added, the README names the classes. Round 2: NEEDS REVISION, 0 blocking, 2 major, 4 minor, 1 nit; fixed: the six-symbol cost is asserted on one line, the Card name wraps at every width (spec 1.0.2), Total is `width:1%` below 640px with one short table in AC-3.11, the stale numbers, AC-7.7 named.

## Global Constraints

These bind every phase. They are the spec's, copied in short.

- The change is documents, `additions.css`, twelve new previews, the stroke of the existing previews, and one new system spec. No view, helper, model, route, query, export, migration or token (spec Non-Goals).
- Build only on the tokens in `app/assets/stylesheets/collector/tokens.css` and the existing `c-*` classes. No colour literal, no hard-coded spacing outside the scale (component sizes such as `96px` and `20px` are lengths, as in `components.css`), no JavaScript, no new gem.
- New CSS goes in `app/assets/stylesheets/collector/additions.css`, each block under its own heading comment ending `(spec 060 …)`. `spec/design_system_files_spec.rb` finds a block by its heading and counts rules up to the next heading: "spec 019" once, "spec 021" once, the image-fit block has no "font", the untabbed-shell block has 3 rules. Never write the text "spec 019" or "spec 021" in a new comment. Run that spec after every `additions.css` edit.
- A chart's numbers are unitless custom properties in a `style` attribute (`--owned`, `--proxy`, `--max`, `--n`); no value in a `style` attribute is a colour (decision 20).
- No RSpec example reads a prose document or a preview (`.claude/rules/testing.md`). Document and preview criteria are verified by reading and recorded in `docs/specs/060-deck-components/verification.md`.
- The deck shell's rules name no format and no game; the samples are a Magic deck and say so (decision 21).
- This change edits no area doc, so no area-doc line needs a citation.
- Commits: small Conventional Commits, one per task. Implementer subagents (Sonnet) end each commit message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call. Never `git push` (the supervisor does, with a CI slot).
- Run Ruby through `script/worktree/with_mise` (this shell's plain Ruby is macOS 2.6). Targeted `script/worktree/with_mise bin/rspec <file>` needs no CI slot; a full `bin/ci` does.
- Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; end every `git grep` with `':!.kamal/secrets'`.
- Subagents share the worktree's test database: never run two test runs at once; batches run one after another.
- The plan's blocks are strong drafts, not pre-run code (`.claude/memory/sdd-execute-exact-plans.md`): run each phase's examples, see them fail for the stated reason, then pass; a fix keeps the spec's behaviour and is recorded as a ruling in the commit body.
- RuboCop in a new system spec: no constants in a `describe` (`RSpec/LeakyConstantDeclaration`), examples at most 15 lines (move measures into helpers), a string `describe` of a file needs an `Exclude` line with its reason in `.rubocop.yml` (`RSpec/DescribeClass`); see `.claude/memory/design-system-guard-and-rubocop-traps.md`. Narrow widths use `open_in_narrow_frame` (an iframe: the window can't go below 500px) or a wrapper `div` of set width for a container query; a 640px frame is 625px wide inside because of the classic scrollbar.

---

## Goal

Six deck components are documented in `docs/design-system/components/`, styled in `collector/additions.css` and proved in a browser, previewed in twelve HTML previews at 1280px and 390px in both themes, and listed in the README; the leftovers of spec 057 are done.

## File map

| File | Responsibility | Phase |
|------|----------------|-------|
| `spec/system/design_system_deck_components_spec.rb` (new) | AC-1.2, 1.3, 2.2–2.7, 3.2–3.9, 3.11, 3.12, 4.2–4.5, 5.2, 5.3, 6.2–6.4 | 1–6 |
| `app/assets/stylesheets/collector/additions.css` | Eight new blocks (below) | 1–6 |
| `docs/design-system/components/ProxyTag.md`, `DeckShape.md`, `DeckPage.md`, `DecksIndex.md`, `AddToDeck.md`, `UseMyCopy.md` (new) | The six documents | 7–9 |
| `docs/design-system/components/ChoicePage.md`, `ManaCost.md`, `TableActions.md`, `AppHeader.md` | One pointer line each; the AppHeader exception | 9 |
| `docs/design-system/README.md` | Components list, App additions line, the Charts rule's hatch, `c-split` out | 9 |
| `docs/design-system/previews/*.html` (twelve new) | FR-6 | 10, 11 |
| `docs/design-system/previews/*.html` (existing) | Icon strokes to 1.5; `ItemPage.html` and `ItemPagePhone.html` indentation | 12 |
| `docs/specs/060-deck-components/verification.md` (new), `docs/specs/README.md` | The record; the Plan column | 13 |

### The new CSS blocks (decision 22), appended at the end of the file, after the Locations block

At the end, not beside the deck-adjacent blocks: `.c-choices { gap:var(--space-2) }` is at line 195 with the same specificity as `.c-pick`'s gap, so a block before it would lose the cascade (review finding 1). The guards read headings, not positions.

1. ProxyTag (spec 060)
2. DeckShape panel and curve (spec 060)
3. DeckShape card types (spec 060)
4. DeckShape mana bar (spec 060)
5. Deck page layout and the panel's two copies (spec 060)
6. Deck page zones (spec 060)
7. Decks list (spec 060)
8. Pick list for AddToDeck and UseMyCopy (spec 060)

## Batches

One Sonnet implementer per batch (test-first, one commit per task); the supervisor reads each batch's diff before the next.

| Batch | Phases | Content |
|-------|--------|---------|
| A | 0–2 | Baseline, ProxyTag, the panel and the curve |
| B | 3–4 | Types and mana bar, the deck page layout and zones |
| C | 5–6 | The Decks list, the pick list |
| D | 7–9 | The six documents, the pointers, the README |
| E | 10–12 | The twelve previews, the strokes and tidy-ups |

The supervisor does Phase 13 (record, screenshots, reviews, CI slot, final visual review).

## Markup reference

One markup per component, used by the spec's helpers, the documents and the previews. Samples are a Magic deck, "Izzet Tempo" (Modern). The 2026-11-10 mock-ups (`tmp/mockups/build.rb` in the supervisor's worktree, not committed) draw all of it with the real CSS.

**ProxyTag:** `<span class="c-proxy">Proxy <b>2</b></span>`

**The panel (`aside` copy):**

```html
<aside class="c-deck__shape">
  <section class="c-shape" aria-labelledby="shape-title-aside">
    <div><h2 class="c-shape__title" id="shape-title-aside">Deck shape</h2><p class="c-shape__scope">Main · 60 cards</p></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Mana curve</h3>
      <div class="c-curve">
        <div role="img" aria-label="Mana curve of the 36 nonland cards in Main: mana value 0, 4 cards (4 owned); 1, 12 cards (11 owned, 1 proxy); … ; 6+, 4 cards (2 owned, 2 proxy). Average mana value 2.3.">
          <div class="c-curve__cols" aria-hidden="true">
            <div class="c-curve__col"><span class="c-curve__count">12</span><div class="c-curve__bar"><div class="c-curve__proxy" style="--proxy:1;--max:12"></div><div class="c-curve__owned" style="--owned:11;--max:12"></div></div></div>
            <!-- six more columns, 0 to 6+; a part of zero has no element -->
          </div>
          <div class="c-curve__labels" aria-hidden="true"><span>0</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6+</span></div>
        </div>
        <ul class="c-curve__legend"><li><span class="c-curve__swatch c-curve__swatch--owned"></span>Owned 30</li><li><span class="c-curve__swatch c-curve__swatch--proxy"></span>Proxy 6</li></ul>
        <p class="c-curve__avg">Average mana value <b>2.3</b></p>
      </div></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Card types</h3>
      <ul class="c-types"><li><span>Lands</span><span class="c-types__n">24</span><span class="c-types__proxy">2 proxy</span></li><li><span>Artifacts</span><span class="c-types__n">4</span><span class="c-types__proxy"></span></li></ul></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Mana symbols</h3>
      <ul class="c-manabar" role="img" aria-label="Coloured mana symbols in Main: blue 44, red 16"><li class="c-manabar__seg c-manabar__seg--u" style="--n:44"><span>U 44</span></li><li class="c-manabar__seg c-manabar__seg--r" style="--n:16"><span>R 16</span></li></ul>
      <p class="c-manacap">Blue 44 · 73% · Red 16 · 27%</p></div>
  </section>
</aside>
```

A type with no proxies keeps an empty `c-types__proxy`, so the counts line up. A mana segment under 10% of the symbols adds `c-manabar__seg--narrow` (its `span` is hidden; the caption carries it). **The `details` copy** (shown below 640px) is `<details class="c-shapefold"><summary><span class="c-shapefold__title">Deck shape</span><span class="c-shapefold__facts">Main · 60 cards · average mana value 2.3</span></summary><div class="c-shape c-shape--bare">…the three c-shape__parts…</div></details>`, with its own title ids.

**The deck page body:** `<div class="c-deck"><details class="c-shapefold">…</details><aside class="c-deck__shape">…</aside><div class="c-deck__zones"><section class="c-zone">…</section>…</div></div>` (DOM order: details, aside, zones).

**A zone:**

```html
<section class="c-zone">
  <div class="c-section__head"><h2 class="c-section__title">Main</h2><span class="c-section__count">60 cards · 52 owned · 8 proxy</span><div class="c-section__actions"><a class="c-btn c-btn--ghost c-btn--sm" href="#"><svg …plus…/>Add a proxy<span class="c-sr"> to Main</span></a></div></div>
  <div class="c-collection"><table class="c-table"><thead><tr>
    <th>Card</th><th class="c-zone__c-cost">Cost</th><th class="c-zone__c-owned is-num is-opt">Owned</th><th class="c-zone__c-proxy is-num is-opt">Proxy</th><th class="c-zone__c-total is-num">Total</th><th class="c-zone__c-menu"><span class="c-sr">Actions</span></th></tr></thead>
  <tbody>
    <tr class="c-zone__group"><th scope="rowgroup" colspan="6">Creatures<span class="c-zone__groupcount">12</span></th></tr>
    <tr><td><div class="c-table__item"><div><a href="#">Murktide Regent</a><span class="is-opt"><br><span class="c-zone__set">MH2 · 52</span></span><span class="c-table__sub"><span class="c-zone__set">MH2 · 52</span> <span class="c-proxy">Proxy <b>2</b></span></span></div></div></td>
      <td><span class="c-cost" role="img" aria-label="Mana cost: 5 generic, 1 blue, 1 blue">…pips…</span></td><td class="is-num is-opt">2</td><td class="is-num is-opt"><span class="c-proxy">Proxy <b>2</b></span></td><td class="is-num">4</td>
      <td class="c-table__actions"><details class="c-menu">…TableActions, trigger "Actions for Murktide Regent MH2 · 52"…</details></td></tr>
  </tbody></table></div>
</section>
```

A card that is not legal in the format has `<span class="c-legal c-legal--no">…cross…Banned</span>` after its name link, at every width. A card with no cost, or no proxy, shows `<span class="is-muted">–</span>`. An empty zone replaces the table with `<p class="c-zone__empty">No cards in Sideboard yet.</p>`.

**The Decks page:** `<main class="c-main c-page c-decks"><div class="c-pagehead"><div><h1 class="c-pagehead__title">Decks</h1><p class="c-pagehead__stats">6 decks · 379 cards</p></div><div class="c-pagehead__actions"><a class="c-btn c-btn--primary" href="/decks/new">…plus…New deck</a></div></div><div class="c-collection"><table class="c-table">…</table></div></main>` with the columns Deck (`TableItemLink`; `c-table__sub` "Modern · 58 owned · Proxy 11"), Format (`is-opt`), Cards (`is-num`), Owned (`is-num is-opt`), Proxy (`is-num is-opt`, the tag or a dash).

**The New deck page:** `c-appbar--detail`; `<div class="c-pagehead"><div><h1 class="c-pagehead__title">New deck</h1></div></div><form class="c-form">` with a `c-field` Name (`c-input`), a `c-field` Format (a native select; `c-field__hint` "The format sets the deck's zones."), `c-form__actions` Create deck (primary) and Cancel (secondary).

**AddToDeck:** `c-appbar--detail`; heading "Add Lightning Bolt to a deck"; `<form class="c-form">`: a `c-field` "Deck and zone" with a select whose options are `Deck › Zone` under `<optgroup label="Decks">` (first option "Choose a deck and zone…"), a `c-field` "How many" (`c-input` number, `min=1`, `value=1`), `<fieldset class="c-choices c-pick"><legend class="c-field__label">What to use</legend>` with `c-check` radios "My copies (3 free: 2 in Blue binder, 1 in Red box)" and "A proxy of `<span class="is-data">2X2 · 117</span>` foil" (both `required`; with only the proxy option it is `checked`), `c-form__actions` Add to deck and Cancel.

**UseMyCopy:** heading "Use my copy of Lightning Bolt"; `c-pagehead__stats` "Replaces 1 proxy in Izzet Tempo › Main · `2X2 · 117` foil"; `<form class="c-form"><fieldset class="c-choices c-pick"><legend class="c-field__label">Which copies</legend><p class="c-pick__group">This printing</p><div class="c-pick__lot"><label class="c-pick__label" for="lot_1">…set · number, finish, condition, place, ×1 free…</label><label class="c-input"><input id="lot_1" type="number" min="0" max="1" value="0" inputmode="numeric"></label></div>…<p class="c-pick__group">Other printings</p>…</fieldset>`, `c-form__actions` Use these copies and Cancel.

---

## Phase 0: Baseline

**Implements:** none | **Satisfies:** none
**Files:** none

- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb spec/system/design_system_deck_rules_spec.rb` — expect `0 failures`. If anything fails, stop and tell the supervisor.

## Phase 1: The spec file and ProxyTag (AC-1.2, AC-1.3)

**Implements:** FR-1 | **Satisfies:** AC-1.2, AC-1.3
**Files:** `spec/system/design_system_deck_components_spec.rb` (new), `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `system_sign_in_as`, `open_in_narrow_frame`, `within_narrow_frame`. Produces: the spec's private helpers `theme`, `add_to_main`, `evaluate`, `computed`, `token`, `box`, `wrap`, `blank_host`, reused by Phases 2 to 6 in the same file.

- [ ] Create the spec file with a header comment: "Spec 060: the CSS the deck components need, proved in headless Firefox on the app's own pages. No deck view exists yet (#49 builds the first), so each component's markup is added to a real page (the Locations page) inside a wrapper `div` whose width the example sets; a container query answers the wrapper's width."
- [ ] Helpers (private methods, copied from `spec/system/design_system_deck_rules_spec.rb`): `theme(name)`, `add_to_main(html)`, `evaluate(script)`, `computed(selector, *properties)`, `token(name)`. Add `box(selector)` returning `{ "left", "top", "right", "bottom", "width", "height" }` from `getBoundingClientRect`, and `wrap(width, html, container: "page")` returning `<div class="c-#{container}" style="width:#{width}px">#{html}</div>` (a table's wrapper is `container: "collection"`).
- [ ] `before { system_sign_in_as(user); visit locations_path; blank_host }`, where `blank_host` clears the host page so its own rules cannot answer the examples: `document.querySelector('main').className = 'c-main c-page'` and `.replaceChildren()` (the Locations page's `c-locations` class gives every `.c-btn` and `.c-input` a 44px floor, `additions.css:375`, which would pass AC-6.2 without the new rule and widen a menu trigger past a 64px column, and its own `.c-form`, `.c-pagehead` would match an unscoped selector). In a narrow frame the same helper runs inside the frame (`within_narrow_frame { blank_host }`). Every selector in an example is scoped to the probe's own `id`.
- [ ] AC-1.2, in `light` and `dark` (`theme(name)`): add `<span class="c-proxy" id="probe">Proxy <b>2</b></span>`; `computed("#probe", "border-top-style", "border-top-color", "color", "height")` equals `[ "dashed", token("--ink-muted"), token("--ink"), "20px" ]`; and its border radius equals the `radius-sm` token (read `--radius-sm` from `tokens.css`, 4px, and use the literal).
- [ ] AC-1.3: the tag's `textContent` matches `/\AProxy\s+2\z/`.
- [ ] Run `script/worktree/with_mise bin/rubocop` on the new file: a `type: :system` spec is not checked by `RSpec/DescribeClass` (`spec/system/design_system_deck_rules_spec.rb` is not in the cop's `Exclude` list either); add an exclusion only if the cop does flag it, with its true reason.
- [ ] Run the spec: expect 2 failures (`border-top-style` is `none`; the tag is unstyled).
- [ ] Append to the end of `additions.css`:

```css
/* ---------- ProxyTag (spec 060): a dashed tag that marks a proxy without colour ---------- */
/* The dashed border and the word carry it; no fill (spec 060 FR-1). The count is mono, like the tables' numbers. */
.c-proxy { display:inline-flex; align-items:center; gap:var(--space-1); height:20px; padding:0 6px; border:1px dashed var(--ink-muted);
  border-radius:var(--radius-sm); font:600 12px/16px var(--font-sans); color:var(--ink); white-space:nowrap; }
.c-proxy b { font:400 12px/16px var(--font-mono); }
```

- [ ] Run the spec and `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb`: green. RuboCop on the new file: clean.
- [ ] Commit: `feat(design-system): ProxyTag, a dashed tag for proxies (spec 060 AC-1.2, 1.3, #249)`

## Phase 2: The panel and the curve (AC-2.2 to AC-2.4)

**Implements:** FR-2 (panel, curve) | **Satisfies:** AC-2.2, AC-2.3, AC-2.4
**Files:** the spec file, `additions.css`
**Interfaces:** Consumes: Phase 1's helpers. Produces: `curve_html(columns)` and `panel_html(curve:, types:, mana:)` builders in the spec; the block "DeckShape panel and curve".

- [ ] `curve_html(columns)` takes seven `[owned, proxy]` pairs and builds the `c-curve` markup of the reference (`--max` is the largest owned plus proxy; a part of zero has no element; the count above a column is owned plus proxy). `panel_html` wraps the curve, a types list and a mana bar (plain strings for now) in `c-shape`.
- [ ] AC-2.2 (a panel at 320px): columns `[[4,0],[11,1],[5,3],[4,0],[4,0],[0,0],[2,2]]`. For each column read the owned and proxy parts' heights: owned = `96 × owned ÷ 12`, proxy = `96 × proxy ÷ 12`, each within 1px; the proxy part's bottom is the owned part's top (within 1px); the count above reads owned plus proxy; the labels read `0 1 2 3 4 5 6+`; `.c-curve__cols` has a 1px `--line-strong` bottom border.
- [ ] AC-2.3, in `light` and `dark`: the owned part's background colour is `token("--ink-muted")`; the proxy part's `background-image` starts with `repeating-linear-gradient` and contains the rgb of `token("--line-strong")` and of `token("--surface-raised")`; its border is 1px `token("--ink-muted")`; no part's colours equal `token("--brand")`.
- [ ] AC-2.4: panels at 320px and at 313px (`wrap(…)`): the panel's `scrollWidth <= clientWidth`; every `.c-curve__count` and `.c-curve__col` right edge is inside the panel's right padding edge; the legend's `scrollWidth <= clientWidth`; the seven columns are each at least 24px wide (so a count of three digits fits). Control (the measure can fail): the same panel at 150px reports `scrollWidth > clientWidth` or a column under 24px.
- [ ] Run: failures (unstyled panel). Add the block:

```css
/* ---------- DeckShape panel and curve (spec 060): a neutral chart, owned solid and proxies hatched on top ---------- */
/* Fills are neutral (README Charts rule, spec 057 decision 10): ink-muted for owned, a hatched line-strong with an
   ink-muted outline for proxies. A column's parts come from custom properties, numbers only (spec 060 decision 20); a part
   of zero is not in the markup, so its borders draw no sliver. box-sizing is border-box because the export sets none. */
.c-shape { display:flex; flex-direction:column; gap:var(--space-6); box-sizing:border-box; padding:var(--space-4); background:var(--surface-raised);
  border:1px solid var(--line); border-radius:var(--radius-md); }
.c-shape--bare { border:0; border-top:1px solid var(--line); border-radius:0; }
.c-shape__title { margin:0; font:600 20px/28px var(--font-sans); color:var(--ink); }
.c-shape__scope { margin:0; font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
.c-shape__part { display:flex; flex-direction:column; gap:var(--space-2); }
.c-shape__heading { margin:0; font:600 14px/20px var(--font-sans); color:var(--ink); }
.c-curve { display:flex; flex-direction:column; gap:var(--space-2); }
.c-curve__cols { display:grid; grid-template-columns:repeat(7, minmax(0, 1fr)); gap:var(--space-1); align-items:end; border-bottom:1px solid var(--line-strong); }
.c-curve__col { display:flex; flex-direction:column; align-items:center; justify-content:flex-end; gap:2px; height:116px; }
.c-curve__count { font:400 12px/16px var(--font-mono); color:var(--ink); }
.c-curve__bar { display:flex; flex-direction:column; width:70%; }
.c-curve__owned, .c-curve__proxy { box-sizing:border-box; border:1px solid var(--ink-muted); }
.c-curve__owned { height:calc(96px * var(--owned) / var(--max)); background:var(--ink-muted); }
.c-curve__proxy { height:calc(96px * var(--proxy) / var(--max));
  background:repeating-linear-gradient(45deg, var(--line-strong) 0 1.5px, var(--surface-raised) 1.5px 5px); }
.c-curve__proxy + .c-curve__owned { margin-top:-1px; } /* the two outlines share one line */
.c-curve__labels { display:grid; grid-template-columns:repeat(7, minmax(0, 1fr)); gap:var(--space-1); text-align:center;
  font:400 12px/16px var(--font-mono); color:var(--ink-muted); }
.c-curve__legend { display:flex; flex-wrap:wrap; gap:var(--space-1) var(--space-4); margin:0; padding:0; list-style:none; font:400 13px/18px var(--font-sans); color:var(--ink); }
.c-curve__legend li { display:inline-flex; align-items:center; gap:var(--space-2); }
.c-curve__swatch { box-sizing:border-box; width:16px; height:12px; border:1px solid var(--ink-muted); border-radius:2px; flex:none; }
.c-curve__swatch--owned { background:var(--ink-muted); }
.c-curve__swatch--proxy { background:repeating-linear-gradient(45deg, var(--line-strong) 0 1.5px, var(--surface-raised) 1.5px 5px); }
.c-curve__avg { margin:0; font:400 13px/18px var(--font-sans); color:var(--ink-muted); }
.c-curve__avg b { font:600 13px/18px var(--font-mono); color:var(--ink); }
```

- [ ] Run the spec, the guard spec and RuboCop: green.
- [ ] Commit: `feat(design-system): DeckShape panel and mana curve (spec 060 AC-2.2 to 2.4, #249)`

## Phase 3: Types and the mana bar (AC-2.5 to AC-2.7)

**Implements:** FR-2 (types, mana bar) | **Satisfies:** AC-2.5, AC-2.6, AC-2.7
**Files:** the spec file, `additions.css`

- [ ] Builders `types_html(rows)` (`[name, owned, proxy]`) and `manabar_html(counts)` (a hash such as `{"U"=>44,"R"=>16}`; adds `c-manabar__seg--narrow` under 10%; builds the caption "Blue 44 · 73% · Red 16 · 27%", each percentage rounded). Update `panel_html` to use them.
- [ ] AC-2.5: rows `Lands 22+2` and `Artifacts 4+0`: the row's name is at the left edge; the two rows' counts have the same right edge within 1px (the empty suffix reserves its width) and the suffix's right edge is the row's content right edge; `Lands` shows "24" and "2 proxy", `Artifacts` shows "4" and an empty suffix (no text); the row's bottom border colour is `token("--line")`; the count's font family is the `--font-mono` token's first family (read with `getComputedStyle(document.documentElement).getPropertyValue("--font-mono")`).
- [ ] AC-2.6, in `light` and `dark`: bar `{"U"=>44,"R"=>16}` in a 288px panel: segment widths in the ratio 44:16 within 1px; the second segment's `border-left` is `1px solid` `--line-strong`; the bar's border is `1px solid` `--line-strong` and its radius is `radius-sm`; each segment's background and colour are the `--mana-u`/`--on-mana-u` and `--mana-r`/`--on-mana-r` tokens in both themes; segment text is "U 44" and "R 16".
- [ ] AC-2.7: bar `{"W"=>3,"U"=>20,"B"=>4,"R"=>18,"G"=>15}` (3/60 = 5%, 4/60 = 6.7%): the W and B segments are narrow and their `span`s are `display:none`; U, R and G show their labels; the caption contains `White 3 · 5%`, `Blue 20 · 33%`, `Black 4 · 7%`, `Red 18 · 30%` and `Green 15 · 25%`.
- [ ] Run: failures. Add the blocks:

```css
/* ---------- DeckShape card types (spec 060): a name, a count, and the proxies in a muted suffix ---------- */
.c-types { margin:0; padding:0; list-style:none; border-top:1px solid var(--line); }
.c-types li { display:flex; align-items:baseline; gap:var(--space-2); min-height:32px; padding:var(--space-1) 0; border-bottom:1px solid var(--line); font:400 14px/20px var(--font-sans); }
.c-types__n { margin-left:auto; font:400 14px/20px var(--font-mono); }
.c-types__proxy { min-width:4.5rem; text-align:right; font:400 12px/16px var(--font-mono); color:var(--ink-muted); } /* reserved even when empty, so the counts line up */

/* ---------- DeckShape mana bar (spec 060): one bar split by colour, the only chart that may use the mana fills ---------- */
/* README Charts rule: every segment has its letter and count (the caption carries a segment under 10%, which the markup
   marks narrow), and a 1px line-strong outline and divider, because the white and black fills vanish on the ground. */
.c-manabar { display:flex; height:32px; margin:0; padding:0; list-style:none; border:1px solid var(--line-strong); border-radius:var(--radius-sm); overflow:hidden; }
.c-manabar__seg { flex:var(--n) 1 0; min-width:0; display:flex; align-items:center; justify-content:center; background:var(--mana-c); color:var(--on-mana-c);
  font:600 12px/16px var(--font-mono); }
.c-manabar__seg + .c-manabar__seg { border-left:1px solid var(--line-strong); }
.c-manabar__seg--w { background:var(--mana-w); color:var(--on-mana-w); }
.c-manabar__seg--u { background:var(--mana-u); color:var(--on-mana-u); }
.c-manabar__seg--b { background:var(--mana-b); color:var(--on-mana-b); }
.c-manabar__seg--r { background:var(--mana-r); color:var(--on-mana-r); }
.c-manabar__seg--g { background:var(--mana-g); color:var(--on-mana-g); }
.c-manabar__seg--narrow span { display:none; }
.c-manacap { margin:0; font:400 13px/18px var(--font-sans); color:var(--ink-muted); }
```

- [ ] Run the spec, the guard spec and RuboCop: green. Commit: `feat(design-system): DeckShape card types and mana bar (spec 060 AC-2.5 to 2.7, #249)`

## Phase 4: The deck page (AC-3.2 to AC-3.9, AC-3.11, AC-3.12)

**Implements:** FR-3 | **Satisfies:** AC-3.2–3.9, 3.11, 3.12 (AC-3.1 and AC-3.10 are document criteria)
**Files:** the spec file, `additions.css`
**Interfaces:** Consumes: the Phase 1–3 builders. Produces: `zone_html(title, rows)` and `deck_html(panel: true)` builders; the blocks "Deck page layout and the panel's two copies" and "Deck page zones".

- [ ] Builders per the Markup reference: `zone_html` takes rows `{name:, set:, cost: (array of symbols or nil), owned:, proxy:, legal: (:legal, :banned…), group:}`, builds `c-cost`/`c-mana` pips as `ManaCost.md` shows, gives the first proxy row the `TableActions` menu; `deck_html(panel: true)` returns `<div class="c-deck">` with the details copy, the aside copy and the zones (`panel: false` omits both copies).
- [ ] AC-3.2 (container 1100px: `wrap(1100, deck_html)`): the zones' left is less than the aside's left; the aside is 320px wide; the gap from the zones' right to the aside's left is 32px; the aside's `position` is `sticky` and `top` is `80px`; the details copy is `display:none`.
- [ ] AC-3.3 at 991px and at 700px: the aside's bottom is at or above the first zone's top; its `position` is `static`; its width equals the zones' width; the details copy is `display:none`; there is no `summary` inside the aside.
- [ ] AC-3.4 at 639px: the aside is `display:none`; the details copy is `display:block`, closed (`open` is false), above the zones, its summary at least 44px high and its text containing "Deck shape" and "average mana value"; focus the summary and `send_keys(:enter)` opens it, a second press closes it; the wrapper's `scrollWidth <= clientWidth`. At 640px the details copy is `display:none` and the aside is displayed.
- [ ] AC-3.5 at a table container of 700px (`wrap(700, zone_html(…), container: "collection")`): the header cells read `Card, Cost, Owned, Proxy, Total, Actions`; a group row's `th` has `colspan` 6, background `token("--surface-sunken")`, `position` `static`, text starting "Creatures" with its count; the row with proxies has a `.c-proxy` in the Proxy cell, the row without has "–"; Owned, Proxy and Total cells are right-aligned and use the mono family.
- [ ] AC-3.6 at a table container of 360px: Owned and Proxy are `display:none`; the Card cell's `.c-table__sub` is displayed and holds the set and (for a proxy row) a `.c-proxy`; Cost and Total are shown; the wrapper's `scrollWidth <= clientWidth` with a worst-case row (a 60-character name with no space and a six-symbol cost); the Cost cell's `scrollWidth <= clientWidth`.
- [ ] A cost that fits (spec 1.0.1): at a table container of 640px a row with a six-symbol cost has its `.c-cost` on one line (its height is one pip, 22px within 1px, and its width 142px within 1px) inside the Cost `td` (176px less 24px of padding); a row with an eight-symbol cost wraps its pips (the `.c-cost`'s height is more than one pip's) and the `td`'s `scrollWidth <= clientWidth`. The first assertion is the one that fails if the Cost column is too narrow (a wrapping `.c-cost` would keep `scrollWidth` within the cell).
- [ ] A name at 640px (spec 1.0.2): at a table container of 640px a row with a 60-character name with no space has the Card `td`'s `scrollWidth <= clientWidth`, and the name link's right edge is at or left of the Cost `td`'s left edge.
- [ ] AC-3.7: a page wrapper at 600px: the counts' top is at or below the title's bottom and "Add a proxy" overlaps the title vertically (its top is above the title's bottom); the counts' `scrollWidth <= clientWidth`; at 700px the head is one line: the counts' top and the button's top are each above the title's bottom (the head aligns on baselines, so tops differ by a few pixels, which is why the example reads overlap, not equal tops).
- [ ] AC-3.8: a banned row's name link is followed by a `.c-legal` containing "Banned", at 700px and at 360px; a legal row has none; the marker's colour is `token("--ink-muted")`.
- [ ] AC-3.9: an empty zone: the counts read `0 cards · 0 owned · 0 proxy`; no `table`; `.c-zone__empty` has background `token("--surface-sunken")` and text `No cards in Sideboard yet.`.
- [ ] AC-3.11: three zone tables with different rows at a 900px collection container: for the Cost, Owned, Proxy, Total and menu `th`s the left edge relative to the table and the width are equal across the three tables, and the widths are 176, 80, 112, 80 and 64px. At 360px (the auto layout) the right edges, relative to the table, of the Cost, Total and menu cells are equal across the tables within 1px, and so are the widths of Total and the menu (spec 1.0.1: Cost's left edge follows its content). One of the three tables has short rows (a zone of "Opt" and one more card), because an auto layout whose content is narrower than the table shares the extra width among its auto columns; Total's `width:1%` below 640px is what keeps it from stretching. If a right edge cannot match, stop and raise a spec update; do not loosen the example.
- [ ] AC-3.12: `deck_html(panel: false)` at 1100px: the zones' left equals the wrapper's left and their width is the wrapper's width minus 352px (320 and 32); at 700px they span the wrapper; there is no `.c-shapefold` and no `.c-deck__shape`.
- [ ] Run: failures. Add the two blocks:

```css
/* ---------- Deck page layout and the panel's two copies (spec 060) ---------- */
/* The shape panel is rendered twice, an aside and a closed details, and each hides the other: a closed details hides its
   content whatever the CSS, and ::details-content would put a browser floor under the page (decision 7). The page's
   container decides, as the rest of a detail page does. Two columns from 992px: 640px of table, 320px of panel and the
   space-8 gap (decision 6). With no panel the second column stays empty (issue design item 7). */
.c-deck { display:grid; grid-template-columns:minmax(0, 1fr); gap:var(--space-6); align-items:start; margin-top:var(--space-6); }
.c-deck__zones { display:flex; flex-direction:column; gap:var(--space-8); min-width:0; }
.c-shapefold { display:none; background:var(--surface-raised); border:1px solid var(--line); border-radius:var(--radius-md); }
.c-shapefold > summary { display:flex; flex-wrap:wrap; align-items:baseline; gap:var(--space-1) var(--space-3); min-height:44px; padding:var(--space-2) var(--space-4); list-style:none; cursor:pointer; }
.c-shapefold > summary::-webkit-details-marker { display:none; }
.c-shapefold > summary::after { content:"Show" / ""; margin-left:auto; font:600 13px/18px var(--font-sans); color:var(--brand); }
.c-shapefold[open] > summary::after { content:"Hide" / ""; }
.c-shapefold > summary:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-md); }
.c-shapefold__title { font:600 20px/28px var(--font-sans); color:var(--ink); }
.c-shapefold__facts { font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
@container page (min-width: 992px) {
  .c-deck { grid-template-columns:minmax(0, 1fr) 320px; gap:var(--space-8); }
  .c-deck__zones { grid-column:1; grid-row:1; }
  .c-deck__shape { grid-column:2; grid-row:1; position:sticky; top:calc(56px + var(--space-6)); } /* the header's 56px, as c-item__media */
}
@container page (max-width: 639px) {
  .c-deck__shape { display:none; }
  .c-shapefold { display:block; }
  .c-zone .c-section__head { flex-wrap:wrap; } /* the counts take their own line: a cut count is information lost */
  .c-zone .c-section__count { order:3; flex-basis:100%; white-space:normal; }
  .c-zone .c-section__actions { margin-left:auto; }
}

/* ---------- Deck page zones (spec 060): a table per zone, grouped rows, one shared column layout ---------- */
/* From 640px of the table's container every zone table has the same fixed widths, so Cost, Owned, Proxy, Total and the
   menu sit at one x in every zone (decision 25). th is border-box: a width is the whole column, padding included. A pip is
   22px (20px and a 1px border; the export sets no box-sizing), so six symbols are 142px and a cell pads 12px a side: Cost
   needs 166px and has 176px. Below 640px the table keeps its auto layout (decision 9): zones are stacked there and a fixed
   Cost would leave a phone's name column 25px. A longer cost wraps its pips, and a long name wraps, at every width rather
   than spill into the next cell. */
.c-zone__group th { position:static; padding:var(--space-2) var(--space-3); background:var(--surface-sunken); font:600 12px/16px var(--font-sans);
  color:var(--ink-muted); border-bottom:1px solid var(--line); } /* the export's .c-table th sticks */
.c-table tr.c-zone__group:hover { background:transparent; }
.c-zone__groupcount { margin-left:var(--space-2); font:400 12px/16px var(--font-mono); }
.c-zone__set { font:400 12px/16px var(--font-mono); color:var(--ink-muted); }
.c-zone__empty { margin:0; padding:var(--space-4); background:var(--surface-sunken); border-radius:var(--radius-md); font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
@container collection (min-width: 640px) {
  .c-zone .c-table { table-layout:fixed; }
  .c-zone .c-table th { box-sizing:border-box; }
  .c-zone .c-table .c-zone__c-cost { width:11rem; }
  .c-zone .c-table .c-zone__c-owned { width:5rem; }
  .c-zone .c-table .c-zone__c-proxy { width:7rem; }
  .c-zone .c-table .c-zone__c-total { width:5rem; }
  .c-zone .c-table .c-zone__c-menu { width:4rem; }
}
@container collection (max-width: 639px) {
  .c-decks td:first-child { white-space:normal; overflow-wrap:anywhere; } /* the export's nowrap: a name never widens a phone's table */
  .c-zone .c-zone__c-total { width:1%; } /* the auto layout shares spare width among auto columns; Total keeps its content's, as the menu does */
}
.c-zone td:first-child { white-space:normal; overflow-wrap:anywhere; } /* every width: in the 128px Card column of a 640px table a name would spill into Cost under the export's nowrap */
.c-zone .c-cost { flex-wrap:wrap; }
```

- [ ] `.c-zone__group th` is one class and one element, as the export's `.c-table th`, and `additions.css` loads after `components.css`, so it wins; if an example shows the group row still sticky or padded as the export's, write `.c-table .c-zone__group th`.
- [ ] Run the spec, the guard spec and RuboCop (split long examples into helpers). Commit: `feat(design-system): the deck page, its zone tables and the panel's two copies (spec 060 AC-3.2 to 3.12, #249)`

## Phase 5: The Decks list (AC-4.2 to AC-4.5)

**Implements:** FR-4 | **Satisfies:** AC-4.2, 4.3, 4.4, 4.5
**Files:** the spec file, `additions.css`

- [ ] Builders `decks_html` (the page head, with `.c-decks` on the wrapper, and the table of the reference) and `new_deck_html`.
- [ ] AC-4.2 at a 700px table container: headers `Deck, Format, Cards, Owned, Proxy`; Cards, Owned and Proxy right-aligned; a deck with proxies has a `.c-proxy`, one without "–".
- [ ] AC-4.3 at 360px: Format, Owned and Proxy hidden; the Deck cell's `.c-table__sub` shows the format, the owned count and the tag; Cards shown; the wrapper's `scrollWidth <= clientWidth` with a 60-character deck name with no space.
- [ ] AC-4.4: in a 360px frame (`open_in_narrow_frame(locations_path, width: 360, ready: ".c-pagehead")`, markup added inside the frame's `main`), the page head inside `.c-decks`: `.c-pagehead__actions` is `display:flex`, the "New deck" `c-btn--primary` is displayed and at least 36px high, and `document.documentElement.scrollWidth <= innerWidth`; the same at 1280px in the page itself (`page.current_window.resize_to(1280, 900)`; the suite's window is 1400px). The 44px target on a coarse pointer is the export's `@media (pointer: coarse) { .c-btn { min-height:44px } }`, which a headless example cannot trigger; `verification.md` quotes that rule. Control (the example can fail): the same head without `.c-decks` has `.c-pagehead__actions` `display:none` at 360px.
- [ ] AC-4.5: the New deck form at 1280px is at most 420px wide; in a 360px frame its fields are stacked (the second field's top is at or below the first's bottom) and the page has no overflow.
- [ ] Run: AC-4.4's phone example fails (`display:none`). Add the block:

```css
/* ---------- Decks list (spec 060): the New deck button stays on a phone ---------- */
/* The export hides a page head's actions below 640px, and the app's header plus means "Add items" everywhere, so the
   Decks page would have no way to add a deck on a phone (decision 24); this page alone keeps its button. A deck's name
   wraps with the zone tables' rule, in the block above (the same selector list). */
@media (max-width: 639px) { .c-decks .c-pagehead__actions { display:flex; } }
```

- [ ] Run the spec, the guard spec and RuboCop. Commit: `feat(design-system): the Decks list keeps New deck on a phone (spec 060 AC-4.2 to 4.5, #249)`

## Phase 6: The pick list (AC-5.2, AC-5.3, AC-6.2 to AC-6.4)

**Implements:** FR-5 | **Satisfies:** AC-5.2, 5.3, 6.2, 6.3, 6.4
**Files:** the spec file, `additions.css`

- [ ] Builders `add_to_deck_html(long: false)` and `use_my_copy_html(long: false)` per the reference (`long: true` puts a 60-character no-space place name in the "My copies" option and in a lot, and a 60-character deck name in the select).
- [ ] AC-5.2 in a 360px frame (`open_in_narrow_frame(locations_path, width: 360, ready: "main")`, markup added in the frame's `main`): `scrollWidth <= innerWidth`; the select's width is at most its form's; the "My copies" label's text right edge is within the fieldset's right edge.
- [ ] AC-5.3: Tab to the first radio (focus the select, then `send_keys(:tab)` twice for the number field and the radio); its `label.c-check` has `outline-style` `solid`, `outline-width` `2px` and `outline-color` `token("--focus")`.
- [ ] AC-6.2 in a 360px frame: each `.c-pick__lot` has a 1px `--line` border and a `--surface-raised` background; its label's bottom is at or above its field's top; the `.c-input` is at least 44px high and its computed width is exactly `96px` (a stretched field would be wider and pass a minimum); the rows are 12px apart (`space-3`); a 60-character no-space place name wraps (the label's `scrollWidth <= clientWidth`); no page overflow.
- [ ] AC-6.3: Tab to a lot's field: its `.c-input` wrapper's `outline` is `2px solid` `token("--focus")` (the export's `c-input:focus-within`); clicking the lot's label focuses the field (`document.activeElement.id` is `lot_1`).
- [ ] AC-6.4: each field's `min` is "0" and `max` equals the lot's free count; its label's text contains the lot's `set · number`, finish, condition and place.
- [ ] Run: failures. Add the block:

```css
/* ---------- Pick list for AddToDeck and UseMyCopy (spec 060): choices that wrap, with a visible focus ---------- */
/* A fieldset is as wide as its widest child, so a long place name in "My copies (…)" would widen the page (spec 042
   AC-7.1's lesson): min-width:0 and a break inside a word. .c-check has no focus ring of its own, so the row shows one
   while its control has keyboard focus. UseMyCopy's lots are bordered blocks, label above field, the field 44px high and
   6rem wide so it is hard to mis-tap, space-3 apart (decision 15). */
.c-pick { min-width:0; gap:var(--space-3); }
.c-pick .c-check { overflow-wrap:anywhere; }
.c-pick .c-check:has(input:focus-visible) { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
.c-pick__group { margin:var(--space-2) 0 calc(var(--space-1) * -1); font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
.c-pick__lot { display:flex; flex-direction:column; gap:var(--space-2); padding:var(--space-3); background:var(--surface-raised);
  border:1px solid var(--line); border-radius:var(--radius-md); }
.c-pick__label { font:400 14px/20px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
.c-pick__lot .c-input { width:6rem; min-height:44px; }
```

- [ ] Run the spec, the guard spec and RuboCop. Commit: `feat(design-system): the pick list of AddToDeck and UseMyCopy (spec 060 AC-5.2 to 6.4, #249)`

---

## Phase 7: ProxyTag and DeckShape documents

**Implements:** FR-1, FR-2 (documents) | **Satisfies:** AC-1.1, AC-2.1
**Files:** `docs/design-system/components/ProxyTag.md`, `DeckShape.md` (new)

Both follow the existing documents: a one-line summary, **Markup** (the reference above), bullets.

- [ ] `ProxyTag.md`: summary "A dashed tag that marks a proxy without colour, so a stand-in is never mistaken for a copy you own." The markup; bullets: the word with the number; 20px, `radius-sm`, 1px dashed `ink-muted`, `ink` text, "Proxy" sans 600 and the number mono; where it is used (the Proxy column of a zone table, the phone's line under a card's name, the Decks list's Proxy cell and phone line); a row with no proxies shows a muted dash and no tag; the card page's In decks Proxy column keeps spec 057's plain count; never a fill, never for anything but proxies; a proxy never counts as owned (README Decks).
- [ ] `DeckShape.md`: summary "A panel that answers what a deck does from the catalog alone: its mana curve, its card types and the coloured mana symbols of its costs. Shown for Magic." The markup (aside copy and details copy); the data each part expects (seven `[owned, proxy]` pairs; types with counts; symbol counts for W, U, B, R, G; the average mana value; the scope line; figures from Main and Commander only; the mana value is `mtg_cards.mana_value` of spec 058 and this spec builds nothing that reads it; how 6+ and half values fall into columns, which faces count and hybrid symbols are #256's); a part of zero is left out of the markup; lands are not in the curve; the `role="img"` and `aria-label` each chart carries and what it reads (every column; every colour); the hatch (45°, 1.5px `line-strong` lines every 5px on `surface-raised`, 1px `ink-muted` outline); counts above columns, legend, average; types: a count and a muted "N proxy"; the mana bar: WUBRG order, the 10% narrow rule, the caption "Blue 44 · 73% · Red 16 · 27%", only W, U, B, R, G; no `brand`, no status colour, `mana-*` only in the bar; the panel works in 279px; the two copies (the aside from 640px, a closed `details` below) and why (decision 7); the numbers are custom properties (decision 20).
- [ ] Commit: `docs(design-system): ProxyTag and DeckShape (spec 060 AC-1.1, 2.1, #249)`

## Phase 8: DeckPage and DecksIndex documents

**Implements:** FR-3, FR-4 (documents) | **Satisfies:** AC-3.1, AC-3.10, AC-4.1
**Files:** `DeckPage.md`, `DecksIndex.md` (new)

- [ ] `DeckPage.md`: summary "One deck at desktop and phone width: its zones as tables and, beside or above them, the shape panel. Shown for a Magic deck; the shell is collectible-agnostic." The markup (the page head as `c-item__head` with the name, the muted line "Modern · 69 cards · 58 owned · 11 proxy", "Edit deck" and a "…" Menu with "Change format" and "Remove deck"; `c-deck`; zones). Bullets: the widths (two columns from 992px of the page container: the panel 320px and sticky at the header's 56px plus `space-6`; below it one column with the panel above, open from 640px and a closed details below 640px; the two copies); the zone head (name, "60 cards · 52 owned · 8 proxy", "Add a proxy" with its `c-sr` tail; the counts on their own line below 640px); the table (columns Card, Cost, Owned, Proxy, Total and the row menu; the fixed widths from 640px of the table's container and why; group rows `th scope="rowgroup"` on `surface-sunken`, the extension supplies the groups (Magic's are top-level types); the Card cell: name as `TableItemLink`, `set · number` mono muted; Cost a `ManaCost` or a muted dash; Proxy the tag or a dash; Total owned plus proxy); the phone columns (Card with the set, the tag and the marker under the name, Cost, Total, the menu); the legality marker (`c-legal c-legal--no`, a cross and the word, only on a card not legal; none in a format with no rules; Banned, Restricted, Not legal); the row menu (`TableActions`; trigger "Actions for <card> <set · number>"; a row with proxies lists Use my copy, Add a new copy, Change proxy count, then, after a `c-menu__sep`, Remove proxy (`c-menu__item--danger`, last, to a confirm page); an owned-only row lists Move copies; Use my copy is `UseMyCopy`, Add a new copy opens the existing Add a copy form with printing, finish and zone filled in; the rest is #254's and #257's); an empty zone (counts "0 cards · 0 owned · 0 proxy", Add a proxy, "No cards in Sideboard yet."); the page with no panel (the second column empty); what the shell names (nothing) and what the extension supplies (the panel, the Cost column, the legality marker, the groups); it is a detail page (`c-appbar--detail`, a back arrow on phones).
- [ ] `DecksIndex.md`: summary "The list of a collector's decks and the page that adds one." The Decks page and the New deck page markup (reference). Bullets: the page head count; "New deck" primary, kept on a phone (decision 24, the exception to `AppHeader.md`); the table columns (Deck as `TableItemLink`, Format, Cards, Owned, Proxy), what Cards counts (every zone, owned plus proxy, Considering included), the Proxy cell, the phone fold (the Deck line "Modern · 58 owned · Proxy 11", Cards stays), the name wrap, no fixed layout (the columns size themselves); the empty state "No decks yet. Add a deck to start building one."; the Decks page lists decks only and Locations places only; the New deck page (heading, Name, a native Format select with its hint, Create deck, Cancel) and its refusals (spec 029's own sentences: blank "Give the location a name.", control character, too long, taken "You already have a location called “<name>”.", and the 500 limit: `Location::MESSAGES`, `Location::FULL`).
- [ ] Commit: `docs(design-system): DeckPage and DecksIndex (spec 060 AC-3.1, 3.10, 4.1, #249)`

## Phase 9: AddToDeck, UseMyCopy, pointers, README

**Implements:** FR-5, FR-6 (documents) | **Satisfies:** AC-5.1, AC-6.1, AC-2.8, AC-7.1, AC-7.6
**Files:** `AddToDeck.md`, `UseMyCopy.md` (new); `ChoicePage.md`, `ManaCost.md`, `TableActions.md`, `AppHeader.md`, `docs/design-system/README.md`

- [ ] `AddToDeck.md`: a `ChoicePage` variant. The markup; bullets per AC-5.1 (the select's options "Deck › Zone" under "Decks" with no Places group and its first option "Choose a deck and zone…"; "My copies" only when copies are free and its sentence "3 free: 2 in Blue binder, 1 in Red box"; the proxy option naming the shown printing; with two options nothing is chosen and the radios are `required`, with one it is chosen; what #255 decides (which lots a count takes, the server's refusals); Cancel returns to the card page; the empty state "You have no decks yet. Add a deck first." with a link "New deck").
- [ ] `UseMyCopy.md`: the markup; bullets per AC-6.1 (the lot row's text, its field named by it, `min` 0 and `max` the free count, 6rem wide and 44px high; the groups; every field 0 at first; the sum from 1 to the row's proxies and the proxy count falls by the copies used; a group with no lot is left out; the empty state "You have no free copy of Lightning Bolt to use." and a link back; the errors "Enter a number from 1 to N." under the group and "Enter a number from 0 to M." under a lot; Cancel returns to the deck).
- [ ] Pointers: `ChoicePage.md` one bullet "`AddToDeck` is a variant: with one option, the option is chosen (spec 060 decision 14)"; `ManaCost.md` one bullet "The mana bar of `DeckShape` is where the Charts rule uses the `mana-*` fills (spec 060)"; `TableActions.md`'s "Used by" gains "and `DeckPage`'s zone tables"; `AppHeader.md`'s "the page head's own buttons hide" gains "(except the Decks page's New deck, spec 060 decision 24)".
- [ ] README: add `DeckShape` and `ProxyTag` (parts) to "Current set" and `DeckPage`, `DecksIndex` (with its New deck page), `AddToDeck` and `UseMyCopy` (screens) to "Full screens"; remove `c-split` from the card-page parts; add one "App additions (spec 060, in `collector/additions.css`)" line naming the components and their classes: `ProxyTag` (`c-proxy`), `DeckShape` (`c-shape`, `c-curve`, `c-types`, `c-manabar`, `c-manacap`), `DeckPage` (`c-deck`, `c-shapefold`, `c-zone`), `DecksIndex` (`c-decks`) and the pick list (`c-pick`) of `AddToDeck` and `UseMyCopy`; in the Charts rule replace "a hatched `line-strong` fill" with "a hatched `line-strong` fill (45°, 1.5px lines every 5px, as `DeckShape` draws it)".
- [ ] Commit: `docs(design-system): AddToDeck, UseMyCopy, the pointers and the README list (spec 060 AC-5.1, 6.1, 7.1, 7.6, 2.8, #249)`

## Phase 10: The previews, parts and the deck page

**Implements:** FR-6 | **Satisfies:** AC-7.2 (part)
**Files:** `previews/ProxyTag.html`, `DeckShape.html`, `DeckPage.html`, `DeckPagePhone.html` (new)

- [ ] Each preview follows `ItemPage.html` (but not its `body { overflow:hidden }`, which would hide a horizontal overflow from the screenshots; AC-7.3's no-overflow reading is a `scrollWidth <= innerWidth` read at each width, not the shot): `<html data-theme="light">`, links in order `preview-fonts.css`, `tokens.css`, `components.css`, `additions.css`; the `?theme=dark` script at the end; the app header (`c-appbar--detail` for a detail page) with five links and the tab bar with Decks current, copied from `ItemPage.html`; icons at stroke 1.5. `ProxyTag.html` shows the tag in a small table and on a phone line. `DeckShape.html` shows the panel at 320px and the `details` copy at 313px side by side (closed and open). `DeckPage.html` is the full page of the reference (Main, Sideboard and Considering of the "Izzet Tempo" sample, one proxy row's menu open, a banned row); `DeckPagePhone.html` is the same markup, as `ItemPagePhone.html` is.
- [ ] Open each in headless Firefox at 1280px and (the Phone one) in a 390px frame in both themes (the supervisor's `tmp/mockups/shoot.rb` is the model); read the console; fix errors. Commit: `docs(design-system): previews of ProxyTag, DeckShape and DeckPage (spec 060, #249)`

## Phase 11: The previews, the Decks pages and the choice pages

**Implements:** FR-6 | **Satisfies:** AC-7.2
**Files:** `previews/DecksIndex.html`, `DecksIndexPhone.html`, `NewDeck.html`, `NewDeckPhone.html`, `AddToDeck.html`, `AddToDeckPhone.html`, `UseMyCopy.html`, `UseMyCopyPhone.html` (new)

- [ ] As Phase 10. `AddToDeck.html` shows the two-option page; `UseMyCopy.html` shows two groups with three lots. Open each at both widths in both themes; read the console. Commit: `docs(design-system): previews of the Decks pages, AddToDeck and UseMyCopy (spec 060, #249)`

## Phase 12: Leftovers and the strokes

**Implements:** FR-6 | **Satisfies:** AC-7.4, AC-7.5
**Files:** `docs/design-system/previews/*.html` (existing), `ItemPage.html`, `ItemPagePhone.html`

- [ ] In every existing preview change each `stroke-width="2"` and `stroke-width="2.5"` to `"1.5"`. Check the 12px icons (the badge and legality marks) at 1.5 in headless Firefox, light and dark: if a check mark is too thin to read at 12px, tell the supervisor before committing (decision 16: "check the 12px marks at 1.5"). `git grep -o 'stroke-width="[0-9.]*"' docs/design-system/previews ':!.kamal/secrets'` then lists only `1.5`.
- [ ] In `ItemPage.html` and `ItemPagePhone.html` remove the two leading spaces of the In decks and Format legality sections (the two files stay identical).
- [ ] Commit: `docs(design-system): preview icons at the app's stroke 1.5 and a tidy indent (spec 060 AC-7.4, 7.5, #249)`

## Phase 13: The record (supervisor)

- [ ] `verification.md`: the browser examples' count and result; AC-7.7 (`bin/ci checks` and `spec/design_system_files_spec.rb`, the full `bin/ci` in the PR); the document criteria's quotations; the screenshots (every new preview at 1280px and 390px, light and dark) in `docs/specs/060-deck-components/screenshots/`; the red runs; the measurements (Cost 176px, 166px needed; the Card column at a 640px container, the 313px and 279px panel); the 12px marks at 1.5.
- [ ] `docs/specs/README.md`: Plan "present". Record in `verification.md`: the Decks table is exempt from decision 25's column layout although FR-4 once pointed at it (FR-4's wording was corrected to the name wrap only); the export's coarse-pointer 44px rule (AC-4.4); the unit pip width (22px).
- [ ] Implementation review (`sdd-review` Mode B, read-only Opus) recorded under `## Implementation review`; the final visual review with the maintainer (screenshots of each new component, both themes, wide and phone, in the PR body, including the tidied lot rows of UseMyCopy); session wrap and distill-feature; a CI slot for the push and the full `bin/ci`.
