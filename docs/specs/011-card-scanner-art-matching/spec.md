# Feature 011: Card Scanner — Art Matching on Live Capture

**Status:** Draft
**Version:** 1.1.3
**Created:** 2026-10-07
**Last Updated:** 2026-10-07
**Branch:** `011-card-scanner-art-matching`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-07 | Initial draft from the approved [PRD](prd.md) |
| 1.1.0 | 2026-10-07 | Spec review revisions (Fable, NEEDS REVISION, nothing blocking). **Maintainer rulings:** each artwork's image is its oldest English card printing's with a `small` image, since bulk-file order isn't kept after a refresh (AC-3.3); the overrule note names what it overruled, the name or the collector line (AC-7.4). **Also:** two generic source hooks, one before the skip decision and one after a run (AC-2.3, AC-2.4); an artwork's printings are active, English, card printings, with a rule for an artwork two cards share (glossary, AC-6.2); "text alone" is spec 009's ranking on the same reading (AC-6.7); a displaced collector-line printing loses its collector-line evidence (AC-6.4); a persisted build run guards concurrency and feeds `catalog:status`, with a Failed line (AC-3.2, AC-3.11); measurement records art on the server by reading key (AC-9.3); the decoder is a development and CI dependency (NFR Reliability); the image fetch extends the Scryfall client (AC-3.4); failed images are retried each build (AC-3.6); the art parameter's shape (AC-6.1); weak art per card (glossary); the live crop pinned to spec 010's (AC-5.3); the opt-in accessor (AC-1.2); the supersession list completed; AC-9.1's cache naming confirmed |
| 1.1.1 | 2026-10-07 | Second spec review (Fable, NEEDS REVISION, nothing blocking). **Fixes:** AC-6.4's language parenthetical removed (English only, as the glossary says); unknown, printing-less and card-less artworks are filtered out before "nearest" is taken, and give no weak art (glossary, AC-6.3); what art overruled is the collector line whenever the text's first candidate carries collector-line evidence, else the name (AC-6.7); the corrected printing is only the one spec 009's ranking already produced (AC-6.4); build runs keep a heartbeat and a short staleness cutoff so a restarted job carries on (AC-3.2, AC-3.8, AC-3.11). **Also:** "oldest" ordering with an undated printing last (AC-3.3); the opt-in read through app configuration that tests set (AC-1.2); the art cache and index under the configured catalog directory (AC-3.4, AC-3.9); the artwork id's form and lenient reading of the art part (AC-6.1); no Artwork row when the art part was dropped (AC-7.1); AC-7.2's badge wording; "tier" defined (AC-6.7); spec 009 AC-2.1 and AC-2.3/2.4 added to Supersedes; a second identical build records only its run (AC-3.8); ADR 0006's representative rule in AC-9.7; the artwork id on the Other printings link (AC-7.5) |
| 1.1.2 | 2026-10-07 | **Maintainer ruling:** weak art is widened. Any text candidate's card, other than the confident-art card, that owns one of the 10 nearest usable artworks holds weak art, whatever its distance. This replaces the PRD's "above 300 bits", under which a second card at or below 300 bits got no art evidence while a card at 400 bits did (glossary, AC-6.5). Still only a tie-break |
| 1.1.3 | 2026-10-07 | Third spec review (Fable, one Important item). **A queue re-run after a restart** finds its own run by job id, marks it interrupted and carries on at once, instead of being skipped by its own fresh heartbeat (AC-3.2, AC-3.8, Error Scenarios); `catalog:status` shows a run with a stale heartbeat as Interrupted (AC-3.11). **Also:** a reading with no text but confident art shows the art candidate rather than "Nothing could be read" (AC-6.3, AC-7.1); the measurement event goes to a run-level file joined by reading key (AC-9.3) |

---

## Problem Statement

The scanner (specs 007 and 009) identifies a card from its name and collector line only. When the collector line gives no usable printing, the name picks the newest printing. That happens on older frames with no set code, on a lost set code, and on faint foil lines. On spec 009's live sitting it caused every miss and correction (30 of 35 right first time). Spec 010 showed that the card's artwork, fingerprinted from the live guide box and searched against an index of every artwork in the catalog, puts the right artwork first for 33 of 35 of the same cards. With art, the right card was in the text top 3 or first by art for 35 of 35, against 31 of 35 for text alone. The index searches in 19 ms on the maintainer's iPhone. This feature builds that into the app, opt-in per instance, because the first build costs a self-hoster about 708 MB of downloads and about 2.6 hours.

> **Inputs.** The [PRD](prd.md) (approved 2026-10-07) and the rulings it records are fixed inputs:
> - the maintainer's ruling of 2026-10-03 (spec 008 [research.md](../008-card-scanner-phase-2-spike/research.md) §14)
> - the ruling of 2026-10-07 (spec 010 [research.md](../010-card-scanner-art-spike/research.md) §8, "The maintainer's ruling")
> - the brainstorm decisions of 2026-10-07
>
> So are the scanner's accepted ADRs:
> - [0004](../../adr/0004-card-recognition-in-the-browser.md): recognition in the browser
> - [0006](../../adr/0006-art-fingerprint-and-index.md): the art fingerprint and an index built on the server from Scryfall `small` images, falling back to another printing's image
> - [0007](../../adr/0007-art-search-in-the-browser.md): search in the browser
>
> **Supersedes:**
> - **Spec 007 FR-3's "send only recognised text":** match results (artwork ids and their distances) are sent too, and no fingerprint is (Story 5, FR-5). Spec 007's `spec.md` gets a versioned update recording this.
> - **Spec 009 AC-5.1's "the name match's card ranks first" and AC-5.2's "the collector-line printing ranks first":** a confident art match ranks above both (Story 6). Spec 009 AC-5.1 and AC-5.2 still decide between the name and the collector line below it, and when there is no confident art match.
> - **Spec 009 AC-5.5's and FR-3's list of evidence kinds:** it gains two art kinds.
> - **Spec 009 FR-5:** the app also receives match results (FR-5 here).
> - **Spec 007 FR-6 (measurement mode):** it also records the art results of Story 9 (AC-9.3).
> - **Spec 009 AC-2.1's "not matched by its collector line → Printing not confirmed":** a confident-art candidate whose artwork belongs to one printing is marked "Matched by its artwork" instead (AC-7.2).
> - **Spec 009 AC-2.3 and AC-2.4's Other printings order:** for a confident-art candidate, the artwork's printings come first (AC-7.5).
>
> The earlier specs keep their text as history. This spec is the current rule for those points.

### Glossary

- **Artwork:** one illustration, identified by Scryfall's `illustration_id`. Several printings of a card can share one artwork, and a card can have several artworks.
- **An artwork's printings:** the catalog printings with its artwork id that the scanner ranks over: not retired, of the ordinary card kind (no art-series cards or tokens), and English, as spec 009's ranking and Other printings are. "The artwork belongs to one printing" and "the newest" are counted over this set. An artwork with none is never matched.
- **The artwork's card:** the card (catalog identity) of the artwork's printings. When the printings belong to more than one card, the artwork's card is the one among the text's candidates with the best name rank; if none of them is a text candidate, the artwork has no card.
- **The usable artworks:** of the artworks a reading sent, those that are in the artwork table, have printings, and have a card. The others are dropped before anything else, so "the nearest artwork" is the nearest usable one, and a dropped artwork gives no evidence of any kind.
- **Fingerprint:** the 1,024-bit value ADR 0006 defines, computed from the art box of a straightened card at the settings frozen at `39cdc6e`.
- **Distance:** the Hamming distance between two fingerprints, from 0 to 1,024 bits. A query keeps each artwork's smallest distance over the six offsets ADR 0006 defines.
- **The art index:** one record per artwork (its id and its fingerprint), built by the app from the catalog and downloaded by the scanner page.
- **The margin:** 300 bits. A named, provisional value (AC-6.2).
- **Confident art:** the nearest usable artwork's distance is at or below the margin.
- **Weak art:** a text candidate's card, other than the confident-art card, owns one of the 10 nearest usable artworks, whatever its distance (maintainer, 2026-10-07, widening the PRD's "above 300 bits"). This holds per card, whether or not another card is confident.
- **Art matching on:** the instance's opt-in setting is set (Story 1).
- **Tier:** the first part of AC-6.6's order on which a candidate qualifies: confident art, strong name, collector line, weak art, or name rank.

## Goals

- A self-hoster can turn art matching on with one documented environment variable. With it off, the app behaves exactly as it does today.
- With it on, the catalog refresh leads to an art index built in the background from the catalog's own images. The build resumes after an interruption, never fetches an image twice, and later fetches only new artworks.
- On live capture, the scanner page searches the art index on the device and sends only the nearest artwork ids and their distances.
- A confident art match ranks first, above a strong name and a collector-line match, and chooses the printing among those sharing its artwork. Weak art only breaks ties between text candidates.
- The confirm step says when art matched, and when it overruled what the text suggested.
- A closing measurement re-scans spec 009's 35 cards on the maintainer's iPhone with the shipped scanner, and reports the results against spec 009 and spec 010, with any confident wrong match named.

## Non-Goals

- Art on the photo-picker path (ruled 2026-10-07).
- Detection on live frames (ruled 2026-10-07).
- Weak art choosing a printing, or adding a card the text didn't find.
- A second condition for "confident", such as a gap to another card's artwork.
- An admin interface for art matching, a rake task only for the art build, or building on boot.
- Changing the fingerprint's settings, or building from `normal` images.
- Choosing a printing by frame era, and foil detection.
- A measurement on unseen cards.
- A pass threshold for any rate.

## Users and Context

**Primary users:** Signed-in collectors scanning cards with live capture on an instance with art matching on, typically on a phone (the maintainer uses Brave, which is WebKit, on an iPhone).

**Secondary users:**
- **Self-hosters,** who decide whether to spend the first build's cost, turn it on, and follow the build's progress.
- **The maintainer,** who runs the closing measurement and rules on the margin.

**Usage context:** As in spec 009, a collector at a table works through a pile of cards. Art matching joins without any extra tap: the same capture produces the text and the art evidence. The art index loads in the background after the scanner starts. On a slow connection, the first scans of a new catalog version can be text only.

**User mental model:**
- Collectors: "it recognises the picture too, and tells me when the picture decided".
- Self-hosters: "a setting that downloads the card images once, in the background, and makes the scanner better".

## User Stories

### Story 1: Turn art matching on

**As a** self-hoster
**I want** to turn art matching on or off with one setting
**So that** my instance spends the download and build only if I want it

**Acceptance criteria:**

- [ ] **AC-1.1** Given the opt-in environment variable is unset, empty or not a recognised true value When the app runs a catalog refresh, renders the scanner, ranks a reading or answers the index URL Then no image is fetched and no art index is built (the refresh itself works as before, including AC-2.3), the index URL answers 404, the scanner page has no index URL and no art status line, and the ranking and confirm step are exactly spec 009's.
- [ ] **AC-1.2** Given `COLLECTOR_MTG_ART_MATCHING` is set to `1`, `true`, `yes` or `on` (any case, surrounding spaces ignored) When the app reads its configuration Then art matching is on. Any other value, including unset or empty, leaves it off. The values are documented. The variable is parsed once, by an MTG-extension accessor that takes the environment as an argument, into the app's configuration (as `config.x.scanner_measurement` is), and every caller (the build, the index URL, the scanner page, the ranking, the status task) reads that configuration. Tests set the configuration value, never the process environment, and the parser has its own unit spec.
- [ ] **AC-1.3** Given the README, `compose.yaml` and `config/deploy.yml` When a self-hoster reads them Then each documents the variable, as `COLLECTOR_MTG_LANGUAGES` is documented. The README states the first build's cost (about 708 MB of downloads, about 2.6 hours of fetching, then fingerprinting, and about 7.3 MB of index), that it runs in the background after a catalog refresh, how to start one now (`catalog:refresh[mtg]`), and how to reclaim the cached images' space after turning art off.
- [ ] **AC-1.4** Given art matching was on and an index exists When the variable is unset and the app restarts Then the index is neither served nor referenced, the scanner works on text alone, and cached images and stored fingerprints are kept.

### Story 2: Artwork ids in the catalog

**As a** self-hoster
**I want** the catalog to know each printing's artwork
**So that** art results can be mapped to printings and cards

**Acceptance criteria:**

- [ ] **AC-2.1** Given a catalog refresh that applies a bulk file When each MTG printing is stored Then its front face's artwork id is stored with it, or nothing when the bulk record has none, and each face's `small` image URI is kept alongside the existing `normal` and `large`. This happens whether or not art matching is on.
- [ ] **AC-2.2** Given an instance upgrading from a version without artwork ids When the migration runs unattended (`db:prepare`) Then it succeeds from any prior version, is reversible, adds an index on the artwork id, and needs no data backfill of its own.
- [ ] **AC-2.3** Given no MTG printing has an artwork id yet (an upgraded instance) When a scheduled refresh finds the source's version already applied Then it applies the bulk file instead of skipping (downloading it if needed), so every printing gets its artwork id. This holds whether art matching is on or off. With at least one printing holding an artwork id, the skip rule is spec 002's.
- [ ] **AC-2.4** Given the collectible-agnostic core When this feature is complete Then core catalog models and tables don't name artworks or art. The artwork id and the `small` URI live in the MTG extension. The core gains at most two generic steps that each source may implement: one asked before the skip decision, which can require an already-applied version to be applied again (AC-2.3), and one run after an applied or skipped refresh (AC-3.1).

### Story 3: Build the art index

**As a** self-hoster with art matching on
**I want** the index built in the background from the catalog's images
**So that** the scanner can match art without any manual step

**Acceptance criteria:**

- [ ] **AC-3.1** Given art matching is on When a catalog refresh applies, or is skipped because its version is already applied while the index is missing or was built for another catalog version or settings digest Then one art build job is enqueued on the catalog's queue. A refresh skipped because another refresh is still running enqueues nothing (the running one will). With art matching off, none is.
- [ ] **AC-3.2** Given an art build is running When another build job starts Then the second ends at once as skipped, and the two never work at the same time. Each build run records the id of the job running it. When a job starts and finds a running run with its own job id (the queue re-ran it after a restart), it marks that run failed as interrupted and carries on at once as a new run. Each build is recorded as a build run (running, finished, failed or skipped, with its counts and times), like the catalog's refresh runs. A running build updates its run's counts and a heartbeat time at least every few minutes (the plan sets the interval). A run whose heartbeat is older than a short cutoff the plan sets (minutes, several intervals) is stale: the next build job to start, whatever its job id, marks it failed as interrupted and proceeds. So a job that the queue re-runs after a restart, or a crashed build, never blocks the next one for hours. The guard doesn't rely on the job queue's concurrency lock alone, because a first build can outlast it.
- [ ] **AC-3.3** Given the catalog's MTG printings When the build chooses each artwork's image Then it uses the front face's `small` image of the artwork's oldest printing that has one: ascending release date with an undated printing last, then set code, then collector number as the catalog orders numbers, among the artwork's printings (glossary). Printings without a `small` image are passed over, so an artwork whose oldest printing has none uses the next (ADR 0006's fallback). Artworks with no image on any of their printings are left out and counted. The choice needs only the catalog, not the bulk file (maintainer, 2026-10-07).
- [ ] **AC-3.4** Given an artwork whose image isn't cached When the build fetches it Then the request:
  - sends the app's descriptive `User-Agent` and `Accept: image/jpeg`
  - waits at least 100 ms after the previous image request
  - has open and read timeouts
  - backs off and retries on 429 (honouring `Retry-After`) and on 5xx, up to 3 attempts in all
  - goes only to the source's allowed image host

  The source's existing client sends `Accept: application/json` only, retries only on 429 and doesn't retry downloads, so the plan extends it or adds an image client beside it, keeping its `User-Agent` and its injectable clock and sleep. The image is written to the art cache under the catalog download directory's `mtg/` folder (`storage/catalog/mtg/` in production and development; the test environment's own directory in tests) through a partial file renamed into place, so a partial download is never taken for an image.
- [ ] **AC-3.5** Given an image is already cached When any later build needs it Then it isn't fetched again.
- [ ] **AC-3.6** Given an image fails after the retries, or can't be decoded When the build continues Then that artwork is recorded as failed in the build run and left out of the index, and the build goes on. A failed artwork is tried again on the next build (about 30 requests a build, by spec 010's count). Only an error outside a single image (the catalog unreadable, the disk full) fails the build.
- [ ] **AC-3.7** Given an artwork without a fingerprint at the current settings digest When the build fingerprints its cached image Then the fingerprint is stored in a global artwork table (no `account_id`) with the printing AC-3.3 chose and the settings digest. The image cache is keyed by artwork id, so a cache seeded from elsewhere (AC-9.1) supplies that artwork's image whichever printing it was taken from. A later build fingerprints only artworks that lack a fingerprint at the current digest.
- [ ] **AC-3.8** Given a build interrupted at any point (the process stopped, the job retried) When the next build runs Then it carries on from the cached images and stored fingerprints, and its result is the same as an uninterrupted build's. This holds when the queue re-runs the job after a restart (AC-3.2's own-job-id rule lets it proceed at once), and when a crashed build's job isn't re-run (the next build job, from the next refresh or a manual `catalog:refresh[mtg]`, finds the run stale and proceeds). Running a complete build twice changes nothing the second time beyond recording the second build run.
- [ ] **AC-3.9** Given every artwork with a usable image has a fingerprint When the build writes the index Then:
  - The file is compressed, named by the catalog version and the settings digest, and holds a header (format version, settings digest, record count) followed by one 144-byte record per artwork: the 16-byte artwork id, then the 128-byte fingerprint.
  - It lives under the same catalog download directory as the art cache (AC-3.4).
  - It is written to a temporary name and renamed into place, so a reader never sees a partial index.
  - The previous index stays in place until the new one is complete, and only the two newest are kept.
- [ ] **AC-3.10** Given the build's decoder (the plan's choice, ADR 0006) When it fingerprints images Then its fingerprints agree with the scanner page's to 0 bits (Story 8) before its index is used.
- [ ] **AC-3.11** Given `bin/rails "catalog:status[mtg]"` When it runs Then it prints an art line:
  - **Off** when art matching is off
  - **Building**, with the images fetched and fingerprinted against the total, while a build is in progress
  - **Ready**, with the artworks indexed, the artworks without an image, the failed images, and the index file in use
  - **Failed**, with the time and message of the last failed build, and the index still in use if any
  - **Interrupted**, for a run still marked running whose heartbeat is past the cutoff, with its last heartbeat time and counts, and the advice to run `catalog:refresh[mtg]` to resume

  When no build has run yet, it says so. The line reflects the most recent build run that wasn't skipped, read from the build runs (AC-3.2) and the artwork table; "Building" shows the running run's latest counts.

### Story 4: Serve the index

**As a** collector's scanner page
**I want** to download the index from the app, once per catalog change
**So that** art can be searched on the device

**Acceptance criteria:**

- [ ] **AC-4.1** Given art matching is on and an index exists When the index's URL is requested Then it answers with the compressed index, marked as gzip-encoded binary whatever the request's `Accept-Encoding` (as spec 010 served it; every supported browser accepts gzip), cacheable publicly and immutably for a year, with a validator the plan chooses. No sign-in is needed: it's global catalog data, as the OCR engine and the catalog pages are.
- [ ] **AC-4.2** Given art matching is off, no index exists, or the requested name isn't the current or previous index When its URL is requested Then it answers 404, and no file outside the art index directory can be named by the request.
- [ ] **AC-4.3** Given a new index is built When the scanner page is next rendered Then it references the new file's URL. The old URL keeps working until the old file is removed.
- [ ] **AC-4.4** Given the index When it is served or cached Then it is never stored under a tenant key, and serving it reads no tenant data.

### Story 5: Art on live capture

**As a** collector
**I want** each live capture to look at the card's artwork as well as its text
**So that** the scanner can find the card when the text can't

**Acceptance criteria:**

- [ ] **AC-5.1** Given art matching is on and an index exists When the scanner page is rendered Then it carries the index's URL and the page's fingerprint settings digest, and shows one muted status line under Capture reading "Loading artwork matching…". With art matching off or no index, there is no URL and no status line.
- [ ] **AC-5.2** Given the scanner page with an index URL When the scanner has started (the camera is running or the photo picker is offered) Then the page downloads the index without delaying the camera or text recognition. On success it checks the header's format version and settings digest against its own: on a match the status line reads "Artwork matching is on"; on a mismatch or a failed download it reads "Artwork matching isn't available. The scanner is reading text only." The status line is a polite live region.
- [ ] **AC-5.3** Given the index is ready When the collector captures from the live camera Then the page:
  - fingerprints the art box of the guide crop: the guide rect in the frame (the same card rect the strips are cut from), taken at the frame's native pixels and rounded outward, not resized, as spec 010's replay cropped it, at ADR 0006's six offsets
  - searches the index for the 10 nearest artworks
  - sends their ids and distances with the reading's text in the same request
- [ ] **AC-5.4** Given a capture from the photo picker, or any capture before the index is ready or after it failed When the reading is sent Then no artwork ids or distances are sent, and the ranking is text only.
- [ ] **AC-5.5** Given any capture in normal use When the page talks to the app Then it sends only the recognised text, the reading key and, under AC-5.3, artwork ids with distances. No frame, strip, photo or fingerprint is sent (FR-5). Development measurement mode may additionally send what spec 007 FR-6 and Story 9 allow.
- [ ] **AC-5.6** Given the fingerprint and search on the device When a live capture is read Then the art work runs alongside text recognition, and doesn't delay the reading by more than the NFR allows.

### Story 6: Art in the ranking

**As a** collector
**I want** a confident art match to decide the card, and its artwork to narrow the printing
**So that** one tap adds the right card more often

**Acceptance criteria:**

- [ ] **AC-6.1** Given a reading request with artworks When it is validated Then the art part, sent as `reading[artworks][][id]` and `reading[artworks][][distance]`, is accepted only with at most 10 entries, each a well-formed artwork id (a UUID in lowercase hex with hyphens, as Scryfall writes `illustration_id`) with a whole-number distance from 0 to 1,024. The art part is read leniently, apart from the text's strict parameters, so a malformed art part never makes the request fail. Otherwise the whole art part is dropped and the text ranks alone; the request is never refused for its art part. A well-formed id that names no artwork in the artwork table is ignored on its own.
- [ ] **AC-6.2** Given the accepted artworks When they are mapped Then each maps to its printings and its card (glossary). Each card keeps its smallest distance. The margin is a named constant, 300 bits, beside the strong-name threshold, and the findings state it and its provenance (provisional, derived from spec 010's guide-path distances on the same 35 cards).
- [ ] **AC-6.3** Given the nearest usable artwork (glossary) is at or below the margin When candidates are ranked Then the artwork's card is the confident-art candidate and ranks first, whatever the name and collector line say, even when the text didn't find it, and even when nothing was read from the text at all: such a reading shows the confident-art candidate rather than "Nothing could be read". At most one card is confident.
- [ ] **AC-6.4** Given a confident-art candidate When its printing is chosen Then:
  - if the artwork belongs to one printing (glossary), that printing, marked as matched by its artwork
  - otherwise, among the artwork's printings: the collector line's printing if it is one of them (including the one-digit-corrected printing spec 009's ranking already produced for this card, when it is its top name candidate; no new cross-check runs), else the newest in the set the collector line read, else the newest, marked "Printing not confirmed"

  A collector-line printing of the same card with a different artwork is not chosen. The art's artwork decides (decided 2026-10-07). The candidate's evidence is then art, plus name if the name matched the card. It doesn't carry collector-line evidence, because the line didn't match the printing shown.
- [ ] **AC-6.5** Given any reading When the candidates other than a confident-art candidate are ranked Then their order is spec 009's, except that among candidates equal on strong name and collector line, a card holding weak art ranks above one without. Between two candidates both holding weak art, or both without, name rank decides, as before. Weak art never adds a card, never outranks a strong name or a collector-line match, and never changes a candidate's printing.
- [ ] **AC-6.6** Given the ranking When a candidate's support is recorded Then it is a set of named evidence kinds: collector line, collector line corrected, name, art, art weak. The order follows the one rule spec 009 AC-5.5 named, now confident art, then strong name, then collector line, then weak art, then name rank. The candidates are still the top 3.
- [ ] **AC-6.7** Given a ranked reading When the confirm step or measurement mode needs to know what decided the order Then the reading exposes, in memory only:
  - the tier of its first candidate
  - whether confident art overruled the text, and what it overruled. "The text alone" is spec 009's ranking over the same reading without its artworks. Art overruled the text when that ranking's first candidate differs from the confident-art candidate in card or in printing. What it overruled is the collector line when that first candidate carries collector-line evidence (plain or corrected), whatever else it carries, and otherwise the name. When that ranking has no candidates, art overruled nothing.
  - the nearest artwork's distance

  Nothing new is stored with a sitting entry.
- [ ] **AC-6.8** Given readings without artworks When they are ranked Then every existing ranking spec from spec 009 passes unchanged.

### Story 7: The confirm step shows art

**As a** collector
**I want** to see when the artwork matched, and when it changed what the name suggested
**So that** I trust the first candidate, or know why it isn't the one the name points to

**Acceptance criteria:**

- [ ] **AC-7.1** Given a reading sent with artworks When "What the scanner read" is shown Then it has an Artwork row:

  | Case | Text |
  |---|---|
  | Confident art | Matched |
  | Weak art on a candidate, no confident art | Looks similar |
  | Neither | No match |

  A reading sent without artworks, or whose art part was dropped (AC-6.1), shows no Artwork row. A reading with no text and no confident art shows spec 009's "Nothing could be read", as today.
- [ ] **AC-7.2** Given a confident-art candidate When it is shown Then:
  - when its artwork belongs to one printing, it carries the success badge "Matched by its artwork"
  - otherwise it carries the evidence line "Matched by its artwork", with the existing "Printing not confirmed" badge when no collector line confirmed the printing

  A collector-line match on the same printing keeps its own badge or evidence too.
- [ ] **AC-7.3** Given a weak-art candidate When it is shown Then it carries the evidence line "Artwork looks similar" and no art badge.
- [ ] **AC-7.4** Given confident art overruled the text (AC-6.7) When the candidates are shown Then one sentence appears above them, naming what it overruled (maintainer, 2026-10-07):

  | Overruled | Card differs | Only the printing differs |
  |---|---|---|
  | The name | "The artwork matches a different card from the one the name suggests. The artwork's match is first." | "The artwork matches a different printing from the one the name suggests. The artwork's match is first." |
  | The collector line | "The artwork matches a different card from the one the collector line suggests. The artwork's match is first." | "The artwork matches a different printing from the one the collector line suggests. The artwork's match is first." |

  It doesn't appear otherwise.
- [ ] **AC-7.5** Given a confident-art candidate whose artwork is shared by several printings When the collector opens its Other printings Then the artwork's printings are listed first, newest first, then the rest in spec 009's order. The Other printings link carries the artwork id, validated as in AC-6.1; an invalid or unknown id is ignored and spec 009's order applies.

### Story 8: The build and the page agree

**As the** maintainer
**I want** proof that the app's server fingerprint and its browser fingerprint are the same
**So that** distances mean the same on both sides

**Acceptance criteria:**

- [ ] **AC-8.1** Given one source of fingerprint settings shared by the build and the page When either computes a fingerprint Then it uses those settings, and the settings digest in the index header, in each stored fingerprint and on the page all come from that source. The settings equal those frozen at `39cdc6e`.
- [ ] **AC-8.2** Given the 134 artworks spec 010 checked (its 34 sitting artworks and 100 others), on the desktop When the shipped build and the shipped page fingerprint each image Then they agree to 0 bits for all 134. The result is reported in the findings before the development index is used for the sitting. No image is committed.
- [ ] **AC-8.3** Given the gating suite When it runs Then it checks agreement between the build and the page on images that may be committed, generated by a test rather than taken from Scryfall (lossless, with no colour profile, so both sides see the same pixels), and a test fails on any difference of more than 0 bits. This checks the arithmetic. Agreement on Scryfall's JPEGs is AC-8.2's gate.

### Story 9: Closing measurement

**As the** maintainer
**I want** spec 009's 35 cards re-scanned live with the shipped scanner and art on
**So that** I can see that the shipped code reproduces the spike, and rule on the margin

**Acceptance criteria:**

- [ ] **AC-9.1** Given the development instance with art matching on When its index is built Then it is built by the shipped job. Its image cache may be seeded from the spike's cache (`~/card-scanner-corpus/art-cache/artwork/small/`, whose files are named by `illustration_id`: spike `art_fetcher.rb` `path_for`, ids from `bulk_artworks.rb`). The findings report the build: artworks indexed, without an image, failed, images fetched by the shipped job, the fetch and fingerprint times, and the index's size stored and compressed.
- [ ] **AC-9.2** Given spec 009's 35 cards (`~/card-scanner-corpus/phase2-sitting/` manifest and ground truth), the iPhone (Brave, LAN, HTTPS) and measurement mode on When the maintainer scans each card once through the live flow with art on, and adds it as in spec 009 AC-9.1 Then the findings report:
  - how many ended as the right printing and finish first time, after a correction (by kind), or wrong, and how many weren't added
  - the right card first
  - each count with its sample size, for foils and non-foils separately
  - the time per card (median and slowest)

  Each is compared with spec 009's sitting on the same cards (30/35 first time, 32/35 in the end) and spec 010's guide path (33/35 right artwork first).
- [ ] **AC-9.3** Given measurement mode When a card is scanned in the sitting Then, besides spec 009 AC-9.2's record, the reading request itself records on the server, outside the repository, a reading event keyed by the reading key, in a file for the whole measurement run rather than the capture's row folder (the capture record and the reading are sent concurrently, so the row may not exist yet). The findings join the two by key, and the page sends nothing extra. The event holds:
  - the artwork ids and distances sent
  - the first candidate's tier
  - whether the overrule note showed
  - whether art overruled a collector-line printing of the same card
  - the nearest and second-nearest artworks' distances, and whether the second belongs to another card
- [ ] **AC-9.4** Given the sitting When the findings are written Then they:
  - name every card that didn't end as the right printing and finish, with its read text, its art distances and likely cause
  - name every confident art match on the wrong artwork, if any
  - state that the margin was derived from these same cards, so the result is biased upwards and isn't an unseen-card rate
  - set no pass threshold

  The maintainer rules on the margin before merge.
- [ ] **AC-9.5** Given the iPhone When the shipped scanner page loads the index cold and warm and searches it during the sitting Then the findings report the download, ready and per-capture art times (median and slowest), compared with spec 010's 244 / 79 / 19 ms.
- [ ] **AC-9.6** Given the sitting's records When they are committed Then they are text-only fixtures under `spec/fixtures/card_scanner/`, prefixed `phase3_shipped_`, keyed by manifest `file`. No image, frame or index is committed.
- [ ] **AC-9.7** Given the findings When they are complete Then ADRs 0006 and 0007 gain the shipped figures (the build's cost and decoder, the phone times) in their Consequences, and the decoder decision is recorded in a new ADR or an amendment to ADR 0006. ADR 0006's Decision is amended to the oldest-English-printing rule for each artwork's image (AC-3.3), replacing "first printing in the bulk file's order".

## Functional Requirements

### FR-1: Opt-in

**Must:**
- Keep art matching off unless the instance's environment variable turns it on (Story 1).
- Make every art behaviour (the build, serving, the page's index URL and status line, art in the ranking and the confirm step) depend on that one setting.

**Must not:**
- Fetch any image, build anything, or change the ranking or any page when it is off.

### FR-2: Catalog and build

**Must:**
- Store the artwork id and `small` image URI in the MTG extension (Story 2). The artwork table, the build runs and the art cache are global catalog data.
- Reach the MTG extension from the core refresh only through the two generic source steps of AC-2.4.
- Write artwork data only through the art build job, which runs after a catalog refresh (Story 3), in batches with short write transactions.
- Make the build idempotent, resumable and incremental (AC-3.5, AC-3.7, AC-3.8).
- Follow the project's rules for external data: allowed host, `User-Agent`, `Accept`, at least 100 ms between requests, timeouts, back-off on 429 and 5xx, no external call during a request or page render, HTTP stubbed in tests.
- Update `CLAUDE.md`'s note that catalog data changes only through `Catalog::Refresh`, adding the art build job.

**Must not:**
- Fetch any image during a web request, on boot, or when art matching is off.
- Put art concepts in the collectible-agnostic core (AC-2.4).

### FR-3: Ranking

**Must:**
- Rank by named kinds of evidence under one rule (AC-6.6), with confident art first (AC-6.3) and weak art only as a tie-break (AC-6.5).
- Choose a confident-art candidate's printing among the printings sharing its artwork (AC-6.4).
- Keep the art evidence and margin inside the MTG extension, beside the strong-name rule.

**Must not:**
- Call any external service while ranking.
- Refuse a reading because of its art part (AC-6.1).

### FR-4: Serving and the scanner page

**Must:**
- Serve the index from the app's own origin under the scanner's existing Content-Security-Policy, and change nothing in that policy unless the plan shows it is required.
- Load the index only on scanner pages, after the scanner has started.

**Must not:**
- Load the index on any page other than the scanner.
- Fetch anything art-related from another host on the device.

### FR-5: Privacy

**Must:**
- Send only recognised text, match results (artwork ids and their distances), the reading key, and the add, Undo and Other printings requests in normal use. This amends spec 007 FR-3 (via a versioned update to spec 007's `spec.md`) and spec 009 FR-5.
- Keep measurement mode development-only and off by default in production and test, with its stored files outside the repository and `storage/`.

**Must not:**
- Send any frame, strip, photo or fingerprint to the app outside development measurement mode, or to any other host at all.
- Store what art matched with sitting entries or anywhere else in normal use.

### FR-6: Design system

**Must:**
- Use the Collector design system's tokens and `c-*` components and its voice for the Artwork row, the art badge and evidence lines, the overrule note and the status line.
- Add any new pattern to `collector/additions.css` with its doc under `docs/design-system/components/`, and update `Scanner.md`.

## Non-Functional Requirements

### Performance

- On the iPhone, the art fingerprint and search add no more than 100 ms (median) to a live capture's reading, measured in the findings (spec 010: 14.5 ms fingerprint and 19 ms search, median).
- Loading the index never delays the camera's start or text recognition's readiness. The findings report both, with and without art matching on.
- On the development machine, art evidence adds no more than 50 ms (median) to the reading request's server time, measured by a non-gating script and reported in the findings.
- The index is downloaded at most once per catalog version and settings digest per browser, and is then served from the browser's cache.
- Suite tests assert behaviour, not time.

### Security

- The index URL serves only the current or previous index file, by name, from the art index directory. Path traversal is impossible, and other names answer 404.
- The art part of a reading is validated against a fixed shape (AC-6.1). Artwork ids are looked up in the artwork table only, with bind parameters.
- The reading request keeps spec 009's authentication, CSRF protection and `Current.account` scoping. The index is public global catalog data and reads no tenant data.
- No art data is cached under a key that omits the account, except the index and artwork table, which are global.

### Reliability

- Migrations are reversible and safe for unattended `db:prepare` from any prior version, with an index on every foreign key and lookup column.
- A failed or interrupted build never removes or corrupts the index in use (AC-3.9), and the scanner works on text alone whenever no usable index is available.
- The build job retries transient errors with back-off and is discarded on a permanent error with the failure logged. Single-image failures never fail the build (AC-3.6).
- The camera page tests (ADR 0002), with art on and off, pass 10 times in a row locally.
- The build's image decoder is a development and CI dependency as well as a production one: `bin/setup`, the CI workflow and the `Dockerfile` all provide it, and the plan's decoder ADR records this.

### Accessibility

- The art status line is a polite live region and announces each change once.
- The art badge, evidence lines and the overrule note use words, not colour alone.
- Nothing new pushes the shutter out of the bottom third of a phone-sized viewport or causes sideways scrolling at 360 px.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Art matching on, but no index yet (first build running) | The page has no index URL and no status line; the scanner is text only; `catalog:status[mtg]` shows the build's progress |
| The index download fails or is cut off on the phone | The status line reads "Artwork matching isn't available. The scanner is reading text only."; captures send no art |
| The index header's settings digest or format version differs from the page's | As for a failed download; the index is ignored |
| A refresh changes the index while a page holds the old one | The page keeps searching the old index; ids no longer in the artwork table are ignored (AC-6.1); the next page load uses the new index |
| Scryfall answers 429 or 5xx for an image | Back off and retry up to the fixed attempts; then record the artwork as failed and go on (AC-3.6) |
| An image can't be decoded | Record the artwork as failed and go on |
| The build is interrupted (deploy, restart, crash) | The next build resumes from the cache and stored fingerprints (AC-3.8); the previous index stays in use meanwhile |
| The disk fills during the build | The build run is marked failed and logged; `catalog:status[mtg]` shows Failed; the previous index stays in use; the partial file is never served |
| The queue re-runs a build job after a restart | The job finds its own run (same job id), marks it failed as interrupted and carries on at once (AC-3.2) |
| A build crashes and its job isn't re-run | `catalog:status[mtg]` shows Interrupted once the heartbeat is past the cutoff; the next build job (next refresh, or `catalog:refresh[mtg]`) marks the run interrupted and proceeds (AC-3.2) |
| A reading's art part is malformed, too long, or out of range | The art part is dropped; the text ranks alone; the reading is not refused |
| Art matching is turned off with an index on disk | The index is not served or referenced; cached images and fingerprints stay |
| The index URL names a file that isn't the current or previous index | 404 |

## Open Questions

None. Resolved in the brainstorm (PRD, 2026-10-07):
- The closing measurement uses spec 009's 35 cards, with the bias stated.
- "Confident" is one absolute threshold, 300 bits, provisional.
- Weak art breaks ties only.
- The build is its own job, enqueued by the refresh.
- The overrule note and the status line are in.
- The work is one spec built in order.

Left to the plan by ADR 0006: the decoder (ImageMagick or `ruby-vips`), recorded in an ADR or an amendment.

## Out of Scope (Future Considerations)

- Art on the photo path, as evidence behind a distance margin (spec 010 recommendation 3).
- Detection within a region around the guide on live frames, or re-tuning `minSeparation` for live framing.
- A gap rule for "confident", using the second-nearest distances Story 9 records.
- Choosing a printing by frame era, and foil detection.
- Other languages, beyond what a shared `illustration_id` already gives non-English printings.
- A published third-party art-hash index, or a server-side search (ADR 0006 Option B, ADR 0007 Options B and C).
- Measuring art on unseen cards, once a new pile is at hand.
