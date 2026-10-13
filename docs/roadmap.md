# Roadmap

**Last ruled on:** 2026-10-11. Goal, 1.0 test and rules: [north-star.md](north-star.md).

The roadmap has one main line, built in order, with a research lane and a housekeeping lane beside it. Each numbered item is a **candidate spec** sized to the north star's one-outcome rule. Candidates are refined, split or dropped when their turn comes; they are not specified ahead.

**Tracking.** Every candidate has a GitHub issue on the [1.0 milestone](https://github.com/plainprogrammer/Collector/milestone/1), labelled by theme (`theme: data-safety`, `theme: typed-entry`, `theme: locations`, `theme: scanner`) or `housekeeping`, with `spike` on the spikes. This file holds the order and the reasons; the issues hold the state. A candidate that is added, split or dropped changes both in the same PR. A spec's PR closes its issue. Build specs that follow a spike get their issue after the maintainer's ruling. Specs 001–015 are done and aren't listed here.

## Main line

### Theme A: Data safety

Foundation principle 2. Spec 004 named export and import as the next priority; specs 007–015 went elsewhere.

1. Record whether Scryfall's terms permit a public, possibly paid, instance (research note; hosted-door rule 1). **Done 2026-10-11:** [research 016](specs/016-scryfall-hosting-terms/research.md), ruled on in decision log 27–29.
2. [#37](https://github.com/plainprogrammer/Collector/issues/37) Define the export format: versioned, keyed by external ids (enabling slice). **Done 2026-10-11:** [the format](export-format/README.md), [ADR 0020](adr/0020-export-format.md) and [spec 017](specs/017-export-format/spec.md), ruled on in decision log 32.
3. [#38](https://github.com/plainprogrammer/Collector/issues/38) Export a collection as a file.
4. [#39](https://github.com/plainprogrammer/Collector/issues/39) Preview an import: per-row errors, nothing written.
5. [#40](https://github.com/plainprogrammer/Collector/issues/40) Apply an import: all or nothing, idempotent, with a round-trip test.
6. [#41](https://github.com/plainprogrammer/Collector/issues/41) Back up and restore an instance, documented and tested. **Expected ADR:** the backup mechanism.
7. [#42](https://github.com/plainprogrammer/Collector/issues/42) Prove an upgrade from the previous release in CI (supports the 1.0 test's third check).

### Theme B: Typed entry

8. [#43](https://github.com/plainprogrammer/Collector/issues/43) Enter cards from a set by collector number and quantity, keyboard only. Nothing in it is specific to one collectible type.

### Theme C: Locations

The design system's "where is it" ([docs/design-system/README.md](design-system/README.md)). The comics research findings feed this design if the research has run by then; it is deferred (ruling 26), and locations don't wait for it.

9. [#44](https://github.com/plainprogrammer/Collector/issues/44) Manage locations (create, rename, remove).
10. [#45](https://github.com/plainprogrammer/Collector/issues/45) Put a lot in a location. **Expected ADR:** how a lot sits in more than one place ([ADR 0019](adr/0019-lot-as-the-unit-of-ownership.md) names the question). It raises the export format to version 2 ([ADR 0020](adr/0020-export-format.md)).
11. [#46](https://github.com/plainprogrammer/Collector/issues/46) Show the location on tiles and rows.
12. [#47](https://github.com/plainprogrammer/Collector/issues/47) Filter the collection by location.
13. [#48](https://github.com/plainprogrammer/Collector/issues/48) Move many lots at once (the "Move to…" deferred in spec 006).
14. [#49](https://github.com/plainprogrammer/Collector/issues/49) Decks as locations.
15. [#50](https://github.com/plainprogrammer/Collector/issues/50) "Free to use" on the card page.
16. [#51](https://github.com/plainprogrammer/Collector/issues/51) Choose a location during typed entry.

### Theme D: Scanner bulk entry

The scanner as built (specs 005 and 007–011) stays as it is until this theme. The spikes may run earlier as measurement only.

17. [#52](https://github.com/plainprogrammer/Collector/issues/52) Spike: the art margin on unseen cards (the 300-bit threshold, kept by ruling in spec 011).
18. [#53](https://github.com/plainprogrammer/Collector/issues/53) Spike: detection on live frames. A build spec follows if the maintainer rules for it.
19. [#54](https://github.com/plainprogrammer/Collector/issues/54) Spike: continuous capture (trigger, duplicates, rate). The build spec follows.
20. [#55](https://github.com/plainprogrammer/Collector/issues/55) Spike: recognising Japanese cards. The build spec follows.
21. Sitting-wide choices, one spec each. This reverses spec 009's deferral of sitting-wide defaults.
    - 21a. [#56](https://github.com/plainprogrammer/Collector/issues/56) Scan a sitting into a location.
    - 21b. [#57](https://github.com/plainprogrammer/Collector/issues/57) Set a condition for a sitting.
    - 21c. [#58](https://github.com/plainprogrammer/Collector/issues/58) Set a language for a sitting.

### Theme E: Comics

Last on the line, so that it can leave 1.0 without reordering anything. Its candidates are written after the maintainer rules on the research. The ruling has three outcomes: in 1.0 at a stated scope, after 1.0, or more research.

## Research lane

Runs beside the main line, when the maintainer starts it.

- **Comics source research** ([issue #23](https://github.com/plainprogrammer/Collector/issues/23)), **deferred on 2026-10-11** (ruling 26); no start is set. It will report the candidate sources, their terms against hosted-door rule 1, and what the data supports for reading state and barcodes.
- Theme D's spikes (items 17–20).

## Housekeeping lane

Taken between specs.

- [#34](https://github.com/plainprogrammer/Collector/issues/34): show the unofficial-content notice and the source attribution in a footer on every page (research 016). **Done 2026-10-12:** [spec 018](specs/018-content-notice-footer/spec.md), [PR #67](https://github.com/plainprogrammer/Collector/pull/67).
- [#35](https://github.com/plainprogrammer/Collector/issues/35): fit card images without cropping (research 016). **Done 2026-10-12:** [spec 019](specs/019-uncropped-card-images/spec.md), [PR #66](https://github.com/plainprogrammer/Collector/pull/66).
- [#59](https://github.com/plainprogrammer/Collector/issues/59): browse the catalog without signing in: search and card pages open to everyone, with the collection parts shown only to a signed-in collector (ruling 27). It is an operator setting, off by default (ruling 30), and a hosted instance turns it on.
- [#19](https://github.com/plainprogrammer/Collector/issues/19): tighten `bin/image-smoke`'s `catalog:status` check.
- [#21](https://github.com/plainprogrammer/Collector/issues/21): record the remaining spec 012 evidence.
- [#31](https://github.com/plainprogrammer/Collector/issues/31): local image builds contain the OCR engine twice.
- [#60](https://github.com/plainprogrammer/Collector/issues/60): the catalog page reads "Running." after a crash until a retry or 15 minutes pass (noted in spec 015). **Done 2026-10-13:** [PR #69](https://github.com/plainprogrammer/Collector/pull/69).
- [#61](https://github.com/plainprogrammer/Collector/issues/61): a retried job shows "Attempts 0" (noted in spec 015). **Done 2026-10-13:** [PR #70](https://github.com/plainprogrammer/Collector/pull/70).
- [#62](https://github.com/plainprogrammer/Collector/issues/62): the catalog search system spec that times out on GitHub CI only. **Done 2026-10-13:** [PR #71](https://github.com/plainprogrammer/Collector/pull/71).
- [#63](https://github.com/plainprogrammer/Collector/issues/63): the README introduction still says accounts and collections aren't built. **Done 2026-10-13:** [spec 020](specs/020-readme-introduction/spec.md), [PR #72](https://github.com/plainprogrammer/Collector/pull/72).
- [#64](https://github.com/plainprogrammer/Collector/issues/64): currency is an instance setting and should be a per-account one (hosted-door rule 3).

## Parked until after 1.0

| Item | Deferred by |
|---|---|
| Market prices, estimated value, "Update prices" | Specs 002, 004, 006; ruling 2026-10-11 |
| Wishlists | Spec 004; ruling 2026-10-11 |
| Lending | Spec 006; ruling 2026-10-11 |
| Personal and household collections side by side | Spec 004 (one user per account); ruling 2026-10-11 |
| Importing files from other tools | Ruling 2026-10-11 |
| Art matching on the photo path | Spec 011; ruling 2026-10-11 |
| Native apps | Spec 005; ruling 2026-10-11 |
| Hosted-service features (billing, limits, hardened sign-up, email, operator backups) | Ruling 2026-10-11 |
| Quick filters (set, finish, condition), grid sort | Specs 004, 006 |
| Scryfall `/migrations`, set-change probe, digital-only printings, search syntax | Spec 002 |
| A general jobs console, settings for schedule and languages in the app | Spec 015 |
| Attestations and SBOMs, GitHub Releases, a version shown in the app | Spec 012 |

The second half of the table wasn't ruled on in the interview. Those items were deferred by their specs and no 1.0 theme needs them.

## Decision log

Rulings by the maintainer. Later planning builds on these and doesn't ask them again.

### 2026-10-11: north-star interview

| # | Question | Ruling |
|---|---|---|
| 1 | What outcome means success in a year? | The maintainer's own and family's collection hosted in Collector, and a hosted offering available. |
| 2 | What form does the hosted offering take? | Undecided. Keep the door open; no commitment to paid, free or invite-only. |
| 3 | What must exist before the family's real collection moves in? | Data safety, locations, comics. Market value is not a blocker. (Comics made conditional by ruling 18.) |
| 4 | In what order? | Data safety, then locations, with the comics source research alongside. (Typed entry placed between them by ruling 16.) |
| 5 | How do family members' collections relate? | Both personal collections and a shared household one. |
| 6 | When does that land? | After 1.0, with no early decision on the ownership model. A format bump and migrations are accepted then. |
| 7 | Where does the scanner stand? | The scanner as built is parked. Bulk entry is the 1.0 need. |
| 8 | Which bulk entry paths are needed for 1.0? | Continuous scanning and fast typed entry. Not importing other tools' files. (Sitting-wide defaults reversed by ruling 20.) |
| 9 | What does comics in 1.0 include? | It depends on the research; the maintainer rules on the scope from its findings. |
| 10 | Which rules keep a hosted service possible? | All four hosted-door rules in the north star. |
| 11 | What marks 1.0? | The three checks of the 1.0 test. No date. |
| 12 | How large is a spec? | One outcome, one PR. |
| 13 | What about foundational decisions with no ADR? | Backfill the load-bearing four: ADRs 0016–0019, each statement confirmed by the maintainer. Hotwire without Node and Solid Queue inside Puma stay as rules. |
| 14 | Which items are confirmed as after 1.0? | Market prices and value; wishlists and lending; hosted-service features. |
| 15 | Which parts of the scanner's tail are in 1.0? | Japanese cards, the unseen-card margin sitting, detection on live frames. Art on the photo path and native apps are after 1.0. |
| 16 | Where does bulk entry sit? | Typed entry after data safety; the scanner work after locations. |
| 17 | Are the instance settings a breach of rule 3? | Only currency. Catalog languages and art matching are operator settings. Scryfall's terms are unchecked and become item 1. |
| 18 | May comics leave 1.0? | Yes: comics may move out of 1.0 entirely on the research ruling. Theme E is last on the line. |
| 19 | Does new collector-owned data extend the export in the same PR? | Yes ("export covers it"). |
| 20 | What does a sitting set once? | Location, condition and language. |
| 21 | Which language does the non-English spike target? | Japanese. |
| 22 | What about the milestone titled "MTG & Comics"? | Renamed on 2026-10-11 to drop comics; they are added back if the ruling puts them in. |
| 23 | Spec 004's admin users page shows copy counts and deletes collections with their users. Is that a breach of "the operator is not the user"? | No. The rule is narrowed to the items in a collection: an admin page never shows or edits them. Account management and aggregate counts are allowed. |
| 24 | Does the goal name the hosted offering? | Yes, as an outcome wanted after 1.0, kept open and not scheduled. |
| 25 | What does issue #23's research produce? | Findings and a recommendation. The maintainer rules on them before any comics spec is written; the issue was updated to say so. |
| 26 | When does the comics source research start? | Deferred for now, with no start set. This replaces "alongside" in rulings 4 and 18; theme C doesn't wait for it. |
| 27 | Does Scryfall pass the "source terms allow hosting" rule? | Yes for a free hosted service. For a paid one: any Wizards of the Coast or Scryfall data is publicly accessible on a hosted instance, with search open to everyone including unauthenticated visitors, and no paid plan is built until Wizards' position is settled. |
| 28 | What about the notice, attribution and image-fit gaps? | A footer notice on every page (issue #34), and the image-fit fix (issue #35). |
| 29 | Are anonymous card pages parked with the hosted-service features? | No. Ruling 27 covers them: card pages are opened with search, as one housekeeping candidate. |
| 30 | Is the catalog open to visitors on every instance? | No. It is an operator setting, off by default; a hosted instance turns it on. |
| 31 | How is the backlog tracked ahead of 1.0? | In GitHub issues on the 1.0 milestone and in this roadmap: one issue per candidate, created on 2026-10-11 (#37–#64, with #19, #21, #31, #34 and #35). |

### 2026-10-11: export format (spec 017)

| # | Question | Ruling |
|---|---|---|
| 32 | What is the export format? | One JSON document per account, keyed by the catalog source's ids, holding the profile, one currency and the lots. Its version is a whole number that rises when an older reader would misread a file or lose the collector's data from it, so locations will make version 2. The rulings are decisions 1 to 20 of [spec 017](specs/017-export-format/spec.md), recorded in [ADR 0020](adr/0020-export-format.md). |
