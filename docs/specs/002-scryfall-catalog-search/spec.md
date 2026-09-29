# Feature 002: Scryfall Catalog Ingestion and Card Search

**Status:** Approved
**Version:** 1.1.1
**Created:** 2026-09-29
**Last Updated:** 2026-09-29
**Branch:** `feat/002-scryfall-catalog-search`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-29 | Initial approved spec |
| 1.1.0 | 2026-09-29 | Spec review revisions: a run applies when the source version *or* the language set changed (AC-4.3, AC-6.2/6.3, FR-4); concurrent-refresh semantics and interrupted runs (AC-4.4–4.6, FR-4); result groups capped at 10 printings with a per-card printings page (AC-1.4, new Story 10, FR-10); groups list every printing of a matching card (AC-1.4, FR-7); literal wildcard matching (AC-1.13); detail URLs keyed by Scryfall ID (AC-3.4, FR-8); Scryfall adapter under `MTG::Scryfall` behind a core `Catalog::Sources` interface (AC-9.2/9.3, FR-3, FR-9); FR-9 covers root `CLAUDE.md`; bulk-format spike (FR-3); clarified sort tie-breakers, blank/invalid input, last-refresh definition, count semantics, artist per face, localized names on multi-face printings, allowed hosts |
| 1.1.1 | 2026-09-29 | Wording clarifications from the implementation review (no behaviour change): AC-8.1 "seen" counts valid records and malformed ones are counted separately; FR-3 allows the English-only `default_cards` file; AC-3.5 link shown only when the card has searchable printings |

---

## Problem Statement

Collector has no catalog data. Every later feature (owned copies, collections, decks, import/export) must point at a trustworthy, locally cached record of what a collectible *is*, and for the first collectible type, Magic: The Gathering, that data comes from Scryfall. The existing design concept (`tmp/docs/catalog-design-concept.md`) builds MTG vocabulary (mana cost, colors, faces, legalities, card-only identity) into the core catalog, which conflicts with Foundation principle 3 (collectible-agnostic core). This feature builds the catalog core and an MTG extension fed from Scryfall, and proves them end to end with a simple public card search served entirely from the local cache.

> **Constraints.** The data source (Scryfall bulk data) and the stack are fixed inputs, not implementation choices. Project rules in `.claude/rules/` override the design concept wherever they conflict. **Naming:** the MTG extension's Ruby namespace is `MTG` (all caps, e.g. `MTG::Printing`), registered as an acronym in the Rails inflector so Zeitwerk maps `app/models/mtg/…` to `MTG::…`. The Scryfall adapter lives in that extension as `MTG::Scryfall`, implementing a collectible-agnostic `Catalog::Sources` interface. `CLAUDE.md`, the rules, and the steering docs that currently say `Mtg::` or `Catalog::Sources::Scryfall` must be updated to match.

## Goals

- A collectible-agnostic catalog core that knows only: collectible types, data sources, groupings of entries (e.g. sets), entries, and a shared "same item" identity that groups entries (for MTG: all printings of one card). An entry has an external ID, a name, a localized name, an identifying number within its grouping, a language, images, a kind, and a retired state.
- An MTG extension that holds every MTG-specific attribute (mana cost, colors, type line, oracle text, faces, rarity, finishes, legalities, etc.) and never leaks those into the core.
- Scryfall data ingested in the background, weekly and on demand: every paper printing in the configured languages (English always included). Only changed printings are written, and printings are never deleted.
- Every refresh run is recorded with its source version, trigger, outcome, and counts, and the operator can inspect those records.
- A public card search by partial name (including localized names) with an optional set filter, grouped by card, 12 cards per page, plus a page listing every printing of one card and a detail page per printing, with no outbound network calls from the server while rendering.

## Non-Goals

- Owned copies, collections, locations, decks, wishlists, allocations.
- Import or export of user collections.
- Authentication, accounts, or tenancy. Catalog data is global; search is public.
- Price data, price history, or marketplace links beyond a single link to the printing's Scryfall page.
- Scryfall's set-change probe, Scryfall's `/migrations` feed, and relinking re-keyed printings.
- Resuming a refresh mid-run after a deploy or restart (a restarted refresh starts over and remains correct).
- Local image caching or hosting.
- An admin web page for refresh status.
- Scryfall-style query syntax (`t:`, `c:`, `set:`), fuzzy or accent-insensitive matching.
- Searching tokens, emblems, and art cards, and ingesting digital-only printings (both deferred; see Out of Scope).
- Any collectible type other than Magic: The Gathering.

## Users and Context

**Primary users:** Visitors to a Collector instance who want to look up Magic cards (currently the maintainer's household).
**Secondary users:** Self-hosters and operators, who keep the catalog current and choose which languages to ingest.
**Usage context:** A visitor opens the search page, types part of a card name (in English or a localized name such as Japanese), optionally picks a set, browses grouped results, and opens a printing's detail page. The operator lets the weekly refresh run on its own and occasionally triggers a refresh by hand or checks run history from the command line.
**User mental model:** "Type a card name, see every printing of that card, click one to see it." Vocabulary: *card* (the gameplay identity, e.g. "Lightning Bolt"), *printing* (one card in one set, one language, one collector number), *set*, *collector number*, *finish* (nonfoil/foil/etched).

## User Stories

### Story 1: Visitor searches for cards by name

**As a** visitor
**I want** to search the catalog by part of a card's name
**So that** I can find a card without knowing its exact name or set

**Acceptance criteria:**

- [ ] **AC-1.1** Given the catalog contains printings of "Lightning Bolt" and "Lightning Helix" When the visitor searches for "lightning bo" Then the results contain the card "Lightning Bolt" and do not contain "Lightning Helix"
- [ ] **AC-1.2** Given the catalog contains "Lightning Bolt" When the visitor searches for "LIGHTNING bolt" Then "Lightning Bolt" is in the results (matching ignores case)
- [ ] **AC-1.3** Given the catalog contains a Japanese printing whose localized name is "稲妻" and whose English name is "Lightning Bolt" When the visitor searches for "稲妻" Then the card "Lightning Bolt" is in the results and the Japanese printing is listed under it
- [ ] **AC-1.4** Given a card with printings in several sets and languages When it appears in results Then it appears exactly once, as one group listing every non-retired printing of that card that passes the set filter (whichever printing's name matched the query), ordered by release date newest first, then set code, collector number, and language
- [ ] **AC-1.4a** Given a card has more than 10 printings that pass the set filter When it appears in results Then its group lists only the 10 newest and shows a "show all N printings" link to that card's printings page (Story 10), where N is the total
- [ ] **AC-1.5** Given a printing is listed in a result group When the visitor views it Then its image, set name, set code, collector number, language, rarity, and available finishes are shown
- [ ] **AC-1.6** Given more than 12 cards match a query When the visitor views the results Then 12 card groups are shown per page, sorted alphabetically by card name (ties broken by card identity), with navigation to the next and previous pages
- [ ] **AC-1.7** Given no card matches the query When the visitor searches Then a "no cards found" message is shown and the response status is 200
- [ ] **AC-1.8** Given the visitor opens the search page with a blank or whitespace-only query and no set selected When the page renders Then no results are listed and a prompt to enter a card name is shown
- [ ] **AC-1.9** Given the catalog contains a token, an emblem, or an art card whose name matches the query When the visitor searches Then that entry is not in the results
- [ ] **AC-1.10** Given a retired printing whose name matches the query When the visitor searches Then that printing is not listed, and a card whose printings are all retired does not appear
- [ ] **AC-1.11** Given no refresh run has ever been recorded as applied When the visitor opens the search page Then a message says the catalog has not been loaded yet
- [ ] **AC-1.12** Given at least one refresh run is recorded as applied When the visitor opens the search page Then the page shows the finish date of the most recent applied run
- [ ] **AC-1.13** Given the catalog contains "Fires of Yavimaya" and no card containing the literal text "Fire_" When the visitor searches for "Fire_" Then no results are listed (`%` and `_` in a query match literally, not as wildcards)
- [ ] **AC-1.14** Given a page number that is not a positive integer or is beyond the last page When the visitor requests it Then the response status is 200 and the first or last page respectively is shown

### Story 2: Visitor narrows search by set

**As a** visitor
**I want** to restrict results to one set
**So that** I can find the printing from the set I'm holding

**Acceptance criteria:**

- [ ] **AC-2.1** Given "Lightning Bolt" has printings in sets A and B When the visitor searches "lightning bolt" with set A selected Then the "Lightning Bolt" group lists only set A's printings
- [ ] **AC-2.2** Given a set is selected and the name query is blank When the visitor searches Then all searchable cards in that set are listed, grouped and paginated as in Story 1
- [ ] **AC-2.3** Given the set filter's list of choices When the visitor opens it Then it lists each set that has at least one searchable printing, by name and code, newest release first
- [ ] **AC-2.4** Given a set code that does not exist is submitted in the request When the search runs Then no results are listed and the response status is 200

### Story 3: Visitor views a printing's details

**As a** visitor
**I want** a page for a single printing
**So that** I can see everything the catalog knows about that physical card

**Acceptance criteria:**

- [ ] **AC-3.1** Given a printing in the catalog When the visitor opens its detail page Then the page shows its name, localized name (if any), image of every face, set name and code, collector number, language, rarity, finishes, release date, and for each face its name, mana cost, type line, rules text, and artist
- [ ] **AC-3.2** Given a printing's detail page When it renders Then it links to the printing's page on Scryfall and shows attribution that card data and images come from Scryfall
- [ ] **AC-3.3** Given a retired printing When the visitor opens its detail page Then the page renders with status 200 and states that the printing is no longer present in the upstream source
- [ ] **AC-3.4** Given a printing When its detail page URL is inspected Then it is addressed by the printing's Scryfall ID (its external ID), not an internal database ID; and given a Scryfall ID that matches no printing When the visitor opens that URL Then the response status is 404
- [ ] **AC-3.5** Given a printing's detail page When it renders and its card has at least one non-retired card-kind printing Then it links to the printings page of its card (Story 10); otherwise no such link is shown (that page would return 404 per AC-10.3)
- [ ] **AC-3.6** Given any search or detail page When the server renders it Then the server makes no outbound network request (images are loaded by the visitor's browser from Scryfall's image host)

### Story 4: Operator gets fresh data on a schedule

**As an** operator
**I want** the catalog to refresh itself weekly
**So that** new sets appear without my intervention

**Acceptance criteria:**

- [ ] **AC-4.1** Given a production deployment When its recurring schedule is inspected Then a catalog refresh for MTG is scheduled once per week, and the schedule is documented in the README
- [ ] **AC-4.2** Given Scryfall publishes a bulk file version that has not yet been applied When a scheduled refresh runs Then the catalog is updated from it and the run is recorded as applied with trigger "scheduled"
- [ ] **AC-4.3** Given the current Scryfall bulk file version has already been applied with the currently configured language set When a scheduled refresh runs Then no catalog rows are written and the run is recorded as skipped
- [ ] **AC-4.4** Given the refresh job When its definition is inspected Then it declares a concurrency limit of one per collectible type, so a second refresh triggered while one runs waits and starts after the first finishes (a waiting scheduled run then skips per AC-4.3)
- [ ] **AC-4.5** Given a run for MTG is recorded as running and started less than 6 hours ago When another MTG refresh starts Then the new run is recorded as skipped with reason "already running" and writes no catalog rows
- [ ] **AC-4.6** Given a run for MTG is recorded as running and started 6 or more hours ago When another MTG refresh starts Then the old run is recorded as failed with error "interrupted" and the new run proceeds

### Story 5: Operator triggers a refresh manually

**As an** operator
**I want** to start a refresh on demand
**So that** I can load the catalog for the first time or pick up changes immediately

**Acceptance criteria:**

- [ ] **AC-5.1** Given a running instance When the operator runs the documented refresh command Then a refresh is queued in the background and the command returns without waiting for it to finish
- [ ] **AC-5.2** Given the current source version has already been applied When the operator triggers a manual refresh Then the refresh runs anyway (the already-applied check is bypassed) and is recorded with trigger "manual"
- [ ] **AC-5.3** Given the README When it is read Then it documents the manual refresh command for both the Compose and Kamal deployment paths

### Story 6: Operator chooses which languages to ingest

**As an** operator
**I want** to configure which languages' printings are ingested
**So that** I can keep the Japanese printings I collect without storing every language

**Acceptance criteria:**

- [ ] **AC-6.1** Given no language setting is configured When a refresh runs Then only English printings are ingested
- [ ] **AC-6.2** Given the last applied run used English only and the language setting is changed to "ja" When the next scheduled refresh runs against the same source version Then it is not skipped, and English and Japanese printings are ingested and no others
- [ ] **AC-6.3** Given Japanese printings were ingested and the operator removes "ja" from the setting When the next scheduled refresh runs against the same source version Then it is not skipped, and on completion the Japanese printings are retired, not deleted
- [ ] **AC-6.4** Given the language setting contains a code the source does not use (e.g. "xx") When a refresh runs Then it fails before downloading, is recorded as failed, and its error names the invalid code
- [ ] **AC-6.5** Given the README When it is read Then it documents the language setting, its format, its default, the accepted codes, and that a change takes effect at the next refresh

### Story 7: Refreshes are safe and incremental

**As an** operator
**I want** refreshes to be idempotent and non-destructive
**So that** a refresh never corrupts the catalog or orphans data that future features will reference

**Acceptance criteria:**

- [ ] **AC-7.1** Given a source file has been applied When the same file is applied again Then the number of catalog rows is unchanged and no printing's last-modified time changes
- [ ] **AC-7.2** Given two consecutive source files where exactly one printing's stored attribute differs When the second is applied Then exactly one printing is updated and the run records 1 updated
- [ ] **AC-7.3** Given two consecutive source files that differ only in fields the catalog does not store (e.g. prices, popularity ranks) When the second is applied Then no printing is written and the run records 0 updated
- [ ] **AC-7.4** Given a printing present in the catalog is absent from a new source file When the refresh completes Then the printing still exists, is marked retired with the retirement time, and the run records it as retired
- [ ] **AC-7.5** Given a retired printing reappears in a later source file When that refresh completes Then the printing is no longer retired, keeps its internal identity, and the run records it as restored
- [ ] **AC-7.6** Given a source file with a printing absent from the catalog When it is applied Then the printing is inserted along with its set and card identity, and the run records it as inserted
- [ ] **AC-7.7** Given a refresh fails partway through When the catalog is inspected Then no printing was retired by that run, every previously ingested printing is still readable, and the run is recorded as failed with an error message
- [ ] **AC-7.8** Given a refresh failed partway through When the next refresh runs Then it completes and leaves the catalog identical to a single successful run of the same source file
- [ ] **AC-7.9** Given a source file containing digital-only printings When it is applied Then no digital-only printing is ingested
- [ ] **AC-7.10** Given a source file containing tokens, emblems, and art cards When it is applied Then they are ingested and stored with their kind (token, emblem, art card), distinguishable from ordinary cards

### Story 8: Operator inspects refresh history

**As an** operator
**I want** to see recent refresh runs
**So that** I can tell whether the catalog is current and why a run failed

**Acceptance criteria:**

- [ ] **AC-8.1** Given refresh runs have happened When the operator runs the documented status command Then it lists the most recent 10 runs, newest first, each with source version, trigger, status, start and finish time, and counts of seen, inserted, updated, retired, restored, and skipped-malformed printings ("seen" counts valid records that passed the language and paper filters, and records that passed the filters but could not be mapped are counted only as skipped-malformed; every count refers to printings only)
- [ ] **AC-8.2** Given a failed run When it is listed Then its error message is shown
- [ ] **AC-8.3** Given a refresh finishes (applied, skipped, or failed) When the application log is inspected Then it contains one structured entry for the run with its status and counts

### Story 9: Contributor sees a collectible-agnostic core

**As a** contributor adding a future collectible type
**I want** the catalog core free of MTG concepts
**So that** I can add a new type by writing an extension and a source adapter, without changing the core

**Acceptance criteria:**

- [ ] **AC-9.1** Given the core catalog's persisted attributes When they are inspected Then none of them is MTG-specific (no mana cost, colors, color identity, power, toughness, loyalty, type line, rules text, legalities, faces, rarity, finishes, frame, border, or security stamp)
- [ ] **AC-9.2** Given the MTG extension, including the Scryfall adapter When it is inspected Then all of its code lives under the `MTG` namespace (the adapter under `MTG::Scryfall`), and `bin/rails zeitwerk:check` passes
- [ ] **AC-9.3** Given the Scryfall integration When it is inspected Then all Scryfall HTTP access and Scryfall-to-catalog field mapping is behind the `MTG::Scryfall` adapter, which implements a collectible-agnostic `Catalog::Sources` interface that the refresh uses without referring to Scryfall or MTG; and the mapping is covered by specs that run without a database or network
- [ ] **AC-9.4** Given `CLAUDE.md`, `.claude/rules/`, and `.claude/memory/steering/` When they are inspected Then they refer to the MTG namespace as `MTG`, not `Mtg`, and name source adapters as implementations of `Catalog::Sources` living in their collectible's namespace (e.g. `MTG::Scryfall`)

### Story 10: Visitor sees every printing of a card

**As a** visitor
**I want** a page listing all printings of one card
**So that** I can find the right printing when a card has been printed many times

**Acceptance criteria:**

- [ ] **AC-10.1** Given a card with 25 non-retired card-kind printings When the visitor opens its printings page Then the card name is shown and the printings are listed newest first (tie-breakers as AC-1.4), paginated at 12 printings per page, each shown as in AC-1.5 and linked to its detail page
- [ ] **AC-10.2** Given a set filter was active on the search that linked to the printings page When the page opens Then only that set's printings are listed, with a control to show all sets
- [ ] **AC-10.3** Given a card identity that does not exist, or has no non-retired card-kind printings When the visitor opens its printings page Then the response status is 404

## Functional Requirements

### FR-1: Collectible-agnostic catalog core

**Must:**
- Represent collectible types, data sources, groupings of entries (sets), entries, and a shared identity that groups entries representing the same item (MTG: one card across all its printings).
- Give every entry: an external ID unique within its collectible type, a display name, an optional localized name, an identifying number within its grouping (MTG: collector number), a language, a kind, a release date, image references, and a retired state with retirement time.
- Give every grouping: a code unique within its collectible type, a name, an optional release date, and an optional parent grouping.
- Support search by name (display or localized), grouping, and kind through the core alone.

**Must not:**
- Contain any attribute or vocabulary specific to MTG or trading cards beyond the generic concepts above.
- Carry an account reference: catalog data is global.

### FR-2: MTG extension

**Must:**
- Live under the `MTG` namespace, with `MTG` registered as an inflector acronym.
- Store MTG-specific printing attributes (rarity, finishes, layout, frame, border, security stamp, variant tags such as promo types and frame effects, legalities, marketplace IDs, faces with name, mana cost, type line, rules text, power, toughness, loyalty, defense, artist, and image references) and MTG card-identity attributes (mana cost, colors, color identity, type line, rules text, keywords).
- Classify each entry's kind as card, token, emblem, art card, or other. (The core defines "card"—in generic terms, the collectible's primary kind—as the searchable kind; extensions add others.)
- Derive a multi-face printing's localized name from its faces' localized names when the source gives none at the top level, so localized search (AC-1.3) works for multi-face printings.

### FR-3: Scryfall source adapter

The adapter lives at `MTG::Scryfall` and implements a collectible-agnostic `Catalog::Sources` interface; the refresh (FR-4) talks only to that interface. Before implementation, a spike confirms Scryfall's bulk-data index fields, the bulk file's encoding and structure, and what the published size refers to, and picks a way to read it record by record; the plan records the result.

**Must:**
- Discover the current bulk file of all printings from Scryfall's bulk-data index and treat its published version as the source version (for an English-only configuration, Scryfall's smaller `default_cards` file, which contains every English printing, may be used instead).
- Download the file in the background into the persistent storage directory, verify its integrity against what Scryfall publishes (per the spike), and retain at most the two most recent downloaded versions.
- Read the file record by record without loading it all into memory.
- Filter out printings whose language is not configured and printings that are digital-only before they are persisted.
- Map each record to the core entry and MTG extension attributes; skip records that fail validation, count them as skipped-malformed, and log their Scryfall ID.
- Load set data from Scryfall's sets listing. A set without a release date is stored without one. A printing referencing a set absent from the listing gets a set created from the printing's own set code and set name.
- Follow Scryfall's API terms: a descriptive user agent and accept header, at least 100 ms between API calls, back-off on HTTP 429, and explicit connect and read timeouts.

**Must not:**
- Be called during a web request.
- Request individual cards from the API as part of a refresh.

### FR-4: Refresh

**Must:**
- Run in the background, at most one at a time per collectible type.
- Record each run: collectible type, source version, trigger (scheduled/manual), status (running/applied/skipped/failed), start and finish times, counts (seen, inserted, updated, retired, restored, skipped-malformed), and error message on failure.
- Skip, recorded as skipped, a scheduled run whose source version has already been applied with the same (sorted) language set; never skip a manual run for that reason.
- Create one run record per attempt, including retries by the job system.
- Allow at most one refresh per collectible type at a time: a second waits its turn; if a run is recorded as running and younger than 6 hours, a new run records itself as skipped ("already running"); if older, the old run is marked failed with error "interrupted" and the new run proceeds.
- Write only printings, sets, and card identities whose stored attributes changed; leave unchanged rows untouched.
- Retire printings not present in a completely processed source file; restore retired printings that reappear.
- Retire only after the full source file has been processed successfully.
- Keep each write transaction short enough that search stays available during a refresh.

**Must not:**
- Delete catalog entries, sets, or card identities.
- Change an existing entry's internal identity when it is updated or restored.

### FR-5: Scheduling and operator commands

**Must:**
- Schedule a weekly MTG refresh in production.
- Provide a documented command that queues a manual refresh.
- Provide a documented command that prints the 10 most recent runs (Story 8).
- Emit one structured log entry per finished run.

### FR-6: Language configuration

**Must:**
- Read the list of additional languages from a documented setting that a self-hoster can change without code changes; always include English.
- Default to English only.
- Reject codes the source does not use, failing the run before download.

### FR-7: Card search

**Must:**
- Be public (no login).
- Match the query as a case-insensitive substring of a printing's display name or localized name.
- Filter by one set when selected; allow a set filter with a blank query.
- Match cards by any of their non-retired card-kind printings; list in each group every non-retired card-kind printing of the card that passes the set filter.
- Return only non-retired printings of kind "card".
- Group results by card identity, 12 groups per page, groups sorted alphabetically by card name (ties by card identity), printings within a group newest release first (ties by set code, collector number, language), at most 10 printings per group with a "show all N printings" link when there are more.
- Treat `%` and `_` in the query literally; treat a whitespace-only query as blank; fall back to the first or last page for invalid page numbers.
- Match case-insensitively for ASCII letters; non-ASCII case folding is not required.
- Show per printing: image, set name and code, collector number, language, rarity, finishes; link to its detail page.
- Show the finish date of the most recent applied run, or a "not loaded yet" message when no run has been applied.
- Keep query and set filter in the URL so a search can be bookmarked and paginated.

**Must not:**
- Make outbound network calls while rendering.
- Show tokens, emblems, art cards, or retired printings.

### FR-8: Printing detail page

**Must:**
- Show the attributes in AC-3.1, a link to the printing on Scryfall, Scryfall attribution, and a link to search results for the card.
- Render retired printings with a notice (AC-3.3).
- Be addressed by the printing's Scryfall ID; return 404 for unknown IDs.

### FR-10: Card printings page

**Must:**
- List every non-retired card-kind printing of one card identity, newest first (tie-breakers as FR-7), 12 per page, optionally restricted to one set.
- Return 404 for an unknown card identity or one with no such printings.
- Make no outbound network calls while rendering.

### FR-9: Conventions update

**Must:**
- Update `CLAUDE.md`, `.claude/rules/`, and `.claude/memory/steering/` so the MTG namespace is written `MTG` and source adapters are described as `Catalog::Sources` implementations living in their collectible's namespace (e.g. `MTG::Scryfall`).

## Non-Functional Requirements

### Performance

- A search request returns in under 500 ms (server time) for any single-page query against a catalog of all English paper printings, on a typical developer machine. (Verified manually against a full catalog, not in the automated suite.)
- A refresh reads the source file record by record; its peak memory stays under 1 GB for an English + Japanese refresh, and a full English-only refresh completes within 60 minutes on a 2 vCPU / 2 GB host. (Verified manually, not in the automated suite.)
- During a refresh, search requests continue to succeed.

### Security

- Search input is used only through bound parameters; set filter values are matched against known sets.
- Scryfall-provided text (names, rules text, URLs) is escaped when rendered; only `https` image and link URLs on Scryfall hosts (`scryfall.com`, `cards.scryfall.io`, `svgs.scryfall.io`) are rendered, and any content security policy in force permits images from those hosts.
- No credentials are needed or stored for Scryfall.
- Specs make no real network calls (WebMock/VCR fixtures for Scryfall responses and a small bulk-file sample).

### Reliability

- A failed or interrupted refresh leaves the catalog readable and consistent (AC-7.7, AC-7.8).
- Scryfall being unavailable never affects search or detail pages.
- All schema changes are reversible and safe to run unattended on boot.
- Catalog tables live in the primary database.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Scryfall bulk-data index unreachable or times out | Run recorded as failed with the error; retried with back-off by the job system; catalog unchanged |
| Scryfall returns HTTP 429 | Adapter backs off and retries; if retries are exhausted, run recorded as failed |
| Downloaded file fails its integrity check | File discarded, run recorded as failed naming the check that failed; catalog unchanged |
| Downloaded file cannot be decoded or parsed | Run recorded as failed; no retirements; catalog otherwise unchanged by that run |
| Single malformed record in an otherwise valid file | Record skipped and logged by Scryfall ID; counted as skipped-malformed; run continues |
| Process killed or deployed mid-refresh | Run is left as running; no retirements happened; a run starting 6+ hours later marks it failed ("interrupted") and completes normally |
| Refresh triggered while one is already running | Second run waits for the first; if the job system lets it start while a run younger than 6 hours is recorded as running, it records itself as skipped ("already running") |
| Invalid language code configured | Run fails before download, recorded as failed with the invalid code named |
| Visitor requests an unknown printing | 404 |
| Visitor requests an unknown card's printings page | 404 |
| Invalid or out-of-range page number | 200, first or last page shown |
| Visitor submits an unknown set code | 200 with no results |
| Catalog never loaded | Search page shows "not loaded yet" message |

## Open Questions

None. Refresh cadence (weekly), tokens/emblems/art cards (ingested but not searchable), digital-only printings (not ingested), and page size (12 cards) were resolved during specification.

## Out of Scope (Future Considerations)

- A search filter to include tokens, emblems, and art cards (already ingested and classified by this feature).
- Ingesting and filtering digital-only (Arena/MTGO) printings.
- Scryfall `/migrations` handling and relinking re-keyed printings.
- Event-driven refreshes triggered by a set-change probe.
- Resuming a refresh across deploys.
- Admin status page for refresh runs.
- Scryfall-style search syntax, fuzzy, accent-insensitive, and non-ASCII case-insensitive matching.
- Local image cache.
- Price data.
- Owned copies, collections, lists, import/export, authentication, and tenancy.
- Additional collectible types.
