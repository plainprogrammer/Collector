# PRD: Card Scanner Art Matching on Live Capture

**Date:** 2026-10-07
**Feature:** 011-card-scanner-art-matching

## Problem

Spec 009's scanner reads a card's name and collector line, and nothing else. On its live sitting of 35 unseen cards, 30 ended right first time ([research.md](../009-card-scanner-confirm-flow/research.md) §8). The misses and corrections share one cause: the collector line gave no usable printing, so the name chose the newest. That happened on older frames with no set code, on a lost set code, and on cards corrected through Other printings.

Spec 010's art spike measured the fix on the same 35 cards, captured live on the maintainer's iPhone ([research.md](../010-card-scanner-art-spike/research.md)):

- **Art from the guide-box crop of a live frame,** with no detection, put the right artwork first for 33 of 35 cards. With art, the right card was in the text top 3 or first by art for 35 of 35, against 31 of 35 for text alone.
- **The full index on the iPhone:** a 6,008,050-byte gzip download (244 ms cold on the LAN), ready in 79 ms, searched in 19 ms median, about 17.5 MB held.
- **The build:** about 708 MB of Scryfall `small` images and about 2.6 hours of throttled fetching for the first index, then about 48 minutes of fingerprinting on the desktop. The index is 7.3 MB (6.0 MB gzip).
- **Art names the exact printing only when its artwork belongs to one printing:** 4 of the 14 printings spec 009's text missed. Otherwise it confirms the card and narrows the printing to those sharing the artwork. Its main gain is the right card, not the printing.

Today none of this is in the app. The catalog has no artwork id, there is no index, and the scanner ranks on text alone.

### The maintainer's rulings this PRD builds on

From 2026-10-03 ([spec 008 research.md](../008-card-scanner-phase-2-spike/research.md) §14):

- Art matching is its own spec, after spec 009.
- It is opt-in per instance, and off by default.
- The artwork id joins the catalog in the MTG extension.
- Spec 007 FR-3 is amended to allow "recognised text and match results — no frame, strip, photo or fingerprint".

From 2026-10-07 (spec 010 [research.md](../010-card-scanner-art-spike/research.md) §8, "The maintainer's ruling"):

- **Live path only.** Spec 011 adds art on the live guide-box crop, with no detection. The photo path gets no art in this spec, and the shipped detector is not run on live frames.
- **Art wins over a name match.** When a confident art match and a strong name match point to different cards, the art match ranks first. This changes spec 009's order, in which a strong name ranked first.
- **The art evidence is grouped by artwork, then by card.**
- **ADR 0006 and ADR 0007 are Accepted.** The index is built on the server from `small` images, falling back to another printing of the same artwork when the first has no image, and it is searched in the browser.
- **The opt-in is an environment variable.** There is no admin interface.
- **The margin is provisional.** Spec 011 sets it from the guide-path distances and confirms it with a closing measurement.

### Decided in this brainstorm (2026-10-07)

- **The closing measurement re-captures spec 009's 35 cards.** No unseen pile is at hand. The margin is derived from these cards, so the result is biased upwards, and the findings say so.
- **"Confident" is one absolute threshold:** the nearest artwork's Hamming distance is ≤ 300 bits (of 1,024), provisionally. On spec 010's guide-path results, 32 of 35 cards had the right artwork first within 300 bits and none had a wrong one. The closest a wrong artwork came while ranked first was 320 bits (Extus, whose artwork has no image).
- **Weak art breaks ties.** Above the margin, art can lift a text candidate above another text candidate in the same tier, but it can't add a card, outrank a strong name or a collector-line match, or choose a printing.
- **The build is its own background job,** enqueued by the catalog refresh when art is on. There is no new rake task and nothing runs on boot.
- **The confirm step says when art overruled the text** (Option B in the brainstorm), and the scanner page shows a quiet status line for the art index (Option B).
- **Approach A: one spec, built in order.** First the catalog artwork id and the build, then serving the index, then search in the scanner page, then the ranking and the confirm step, and last the closing measurement. Each step leaves the app working. Before the scanner step, collectors see no change.

## Users & Context

**Collectors** using the scanner's live capture on an instance with art matching on. They hold a card in the guide, capture it, and confirm what to add. They want the right card and printing first more often, and to be told why when art changed the answer.

**Self-hosters** decide whether their instance spends about 708 MB and about 2.6 hours on the first build. They turn art on with an environment variable and follow the build in `catalog:status[mtg]`. An instance with art off behaves exactly as it does today.

**The maintainer** runs the closing measurement on the iPhone and rules on the margin.

**What it touches:**

- **The catalog refresh.** `Catalog::Refresh`, `Catalog::RefreshJob` (`sync` queue, one at a time per collectible type), the MTG source, `MTG::Scryfall::Mapper` and `MTG::Scryfall::Client` (its `User-Agent`, timeouts and 429 back-off). Bulk files live in `storage/catalog/mtg/`.
- **`mtg_printings`.** It holds `faces` JSON with `normal`/`large` image URIs only, and no artwork id.
- **The scanner page.**
  - `card_reader_controller.js`: a live capture has the full frame and the guide rect in frame pixels, the natural place to crop the art box.
  - `geometry.js` defines the guide.
  - `POST /scanner/readings` sends the text and the reading key, and answers with a Turbo Stream.
- **`MTG::Reading`'s ranking.** `Candidate` has evidence kinds `:collector_line`, `:collector_line_corrected` and `:name`. One rule decides the order: `rank_key = [strong_name, collector_line, name_rank]`. Spec 009 AC-5.5 left a named place for "a later kind of evidence, such as an art match".
- **The confirm step's partials:** `scanners/_result`, `scanners/_candidate`, and Other printings through `Scanner::OtherPrintings`.
- **The scanner pages' Content-Security-Policy** (`ScannerPage`). `connect-src 'self'` already allows fetching the index from the app.
- **`OcrAssetsController`,** the precedent for serving a public, immutable, versioned file.
- **The production image.** It has libvips but no ImageMagick, and `ruby-vips`/`ffi` are not in the bundle. The spike's Ruby fingerprint decoded with the `magick` CLI.
- **The spike's art code** (`spikes/card_scanner/phase2/`: the bulk-artwork reader, the throttled fetcher, the Ruby and browser fingerprints, the index format and the search). Its settings are frozen at `39cdc6e`. The shipped code reimplements them in the app; nothing in the app loads spike code.

## Goals

1. **Opt-in per instance.**
   - `COLLECTOR_MTG_ART_MATCHING` turns art matching on. It's read through the source's injected `env:`, like `COLLECTOR_MTG_LANGUAGES`.
   - It's off by default.
   - It's documented in `compose.yaml`, `config/deploy.yml` and the README, with the first build's cost.
   - With it off, nothing is fetched or built, no index is served or referenced, and the scanner and its ranking behave exactly as today.

2. **The artwork id in the catalog.**
   - `mtg_printings` gains an indexed `illustration_id`, taken from the front face. It is nullable, because some printings have none.
   - The mapper also keeps each face's `small` image URI.
   - Existing instances fill both on their next applied refresh: the content digest changes, so every printing is rewritten once in the existing batches.
   - A refresh that would skip while printings lack artwork ids applies instead, following the name index's "rebuild if missing" precedent.
   - All of this lives in the MTG extension. The collectible-agnostic core gains only a generic after-refresh hook on the source, which never names art.

3. **The build.**
   - **The table.** `mtg_artworks` is global catalog data with no `account_id`. It holds one row per `illustration_id`: the printing whose image was used, the 128-byte fingerprint, and the digest of the fingerprint settings it was made with.
   - **The image for each artwork.** The first printing in bulk-file order that has a `small` image. If it has none, another printing of the same artwork that does. Artworks with no image on any printing are left out and counted.
   - **When it runs.** A background job on the `sync` queue, at most one at a time, enqueued after an applied refresh when art is on. It's also enqueued after a skipped refresh if the index is missing or stale.
   - **Incremental.** A later build fetches and fingerprints only artworks without a current fingerprint.
   - **Fetching.**
     - The client's `User-Agent` and `Accept: image/jpeg`.
     - At least 100 ms between requests.
     - Open and read timeouts.
     - Back-off on 429 and 5xx.
     - Images are cached at `storage/catalog/mtg/art/small/<illustration_id>.jpg` through a partial file and never fetched twice, so an interrupted build resumes.
     - A failed image is recorded and skipped, and doesn't fail the build.
   - **The fingerprint.**
     - It is ADR 0006's, at the settings frozen at `39cdc6e`: the art box, four planes resampled by area to 17×16, and horizontal neighbour differences, 1,024 bits in all.
     - The index stores the zero-offset fingerprint; queries try six offsets.
     - One settings source serves both Ruby and the browser, and its digest is recorded in every row and in the index.
   - **The decoder** is the plan's choice (ImageMagick or `ruby-vips`). Whichever it is must agree with the browser's fingerprint to 0 bits before its index is used.

4. **The index file, served.**
   - **The file.** One gzipped file, named by catalog version and settings digest. It has a small header (format version, settings digest, record count) followed by ADR 0006's 144-byte records (a 16-byte artwork id and the 128-byte fingerprint).
   - **Written atomically.** The previous index stays in place until the new one is complete, and the two newest are kept.
   - **Served** by a controller modelled on `OcrAssetsController`:
     - public, because it's global catalog data
     - pre-gzipped with `Content-Encoding: gzip`
     - `Cache-Control: public, immutable`, for a year
     - a 404 when art is off or there's no index
     - never cached under a tenant key

5. **Search on the live path.**
   - **Loading.** When art is on and an index exists, the scanner page is given its URL and loads it after the scanner has started, so the camera and text recognition never wait for it.
   - **The settings check.** The page checks the index header's settings digest against its own. On a mismatch, or a failed load, it ignores the index.
   - **On each live capture,** the page fingerprints the art box of the guide crop at the six offsets and searches the index. It sends the 10 nearest artworks as `reading[artworks][]`, an id and a distance each, alongside the text.
   - **When no art is sent:** the photo path, captures made before the index is ready, and an instance with art off.
   - **What is never sent:** a frame, strip, photo or fingerprint.
   - **Spec 007 FR-3 is amended** to: send only recognised text and match results (artwork ids and their distances) to the app in normal use; must not send any frame, strip, photo or fingerprint outside development measurement mode.

6. **Art evidence in the ranking.**
   - **Validation.** `MTG::Reading` takes the artworks after validation: at most 10, well-formed ids, distances from 0 to 1024. Invalid art is dropped and the text ranks alone; it is never a 422.
   - **Grouping.** Artworks map through `mtg_artworks` and `mtg_printings.illustration_id` to printings and then to cards. Each card keeps its smallest distance.
   - **Confident art (new, first).** The card owning the nearest artwork, when that distance is ≤ 300 bits. At most one card is confident. It joins the candidates even if the text didn't find it.
     - Its printing is the artwork's only printing, if it has just one.
     - Otherwise, among the printings sharing the artwork: the collector-line match if it's one of them, else one in the read set, else the newest.
     - Art wins over a collector-line match of the same card with a different artwork.
   - **Strong name, collector line and name rank** work as in spec 009.
   - **Weak art (new, fourth).** A text candidate whose card owns one of the 10 nearest artworks, above 300 bits. It reorders cards only and never picks a printing.
   - **The rank key** becomes `[confident_art, strong_name, collector_line, weak_art, name_rank]`, still in the one place AC-5.5 named, and the candidates are still the top 3.
   - **The margin** is a named constant beside `STRONG_NAME_SCORE`.
   - **The tier that decided** is recorded on the reading, for the confirm step and the measurement.

7. **The confirm step and the scanner page.** All copy follows the design system's voice and uses the existing `c-*` classes; the spec goes through the `collector-design-system` skill.

   **"What the scanner read" gains an Artwork row:**

   | Case | Text |
   |---|---|
   | Confident art | Matched |
   | Only weak art | Looks similar |
   | Art sent, nothing confident or similar | No match |
   | No art sent | row not shown |

   **Each candidate shows its art evidence:**
   - When art names the artwork's only printing: the success badge "Matched by its artwork".
   - When several printings share the artwork: the evidence line "Matched by its artwork", beside the existing "Printing not confirmed" badge.
   - For weak art: the evidence line "Artwork looks similar".

   **When confident art overrules the text** (its card or printing differs from what text alone would have put first), one sentence appears above the candidates:
   - "The artwork matches a different card from the one the name suggests. The artwork's match is first."
   - "The artwork matches a different printing from the one the name suggests. The artwork's match is first."

   **Other printings** lists the printings that share the artwork first, when there are several.

   **The scanner page** shows one quiet status line under Capture, only when the instance has art on. It reads, in turn:
   - "Loading artwork matching…"
   - "Artwork matching is on"
   - "Artwork matching isn't available. The scanner is reading text only."

   It is a polite live region.

8. **Visibility for self-hosters.** `catalog:status[mtg]` gains an art line:
   - **Off**
   - **Building:** images fetched and fingerprinted, against the total
   - **Ready:** artworks indexed, artworks without an image, failed images, and the index file in use

   Turning art off stops serving and referencing the index. Cached images stay, and the README says how to reclaim the space.

9. **The closing measurement.**
   - **The build gate, first.** On the desktop, the shipped Ruby build and the shipped browser fingerprint agree to 0 bits on the 134 artworks spec 010 checked (34 sitting cards and 100 others).
   - **The development index** is built by the shipped job. The plan may seed its image cache from the spike's cache (`~/card-scanner-corpus/art-cache/artwork/small/`, 50,924 files named by artwork id; the plan confirms they are `illustration_id`s), so the job fetches only what's new since that bulk file.
   - **The sitting.** The maintainer goes through spec 009's 35 cards on the iPhone (Brave, LAN, HTTPS) with the shipped scanner and art on, adding each card through the confirm flow. Measurement mode, development only, also records each capture's artworks, distances and deciding tier, outside the repo.
   - **Per card,** the findings report:
     - the outcome: right printing and finish first time, right after a correction, wrong, or not added
     - whether the right card was first
     - the nearest artwork's distance
     - the deciding tier
     - whether the overrule note showed
   - **On the phone,** they report the shipped page's index download, ready and search times.
   - **Compared with** spec 009's text-only sitting (30/35 right first time, 32/35 in the end) and spec 010's guide path (33/35 right artwork first).
   - **The margin check.** Any confident art match on the wrong artwork is a finding, and the maintainer rules on the margin before merge. There is no pass threshold.
   - **Committed results** are text-only fixtures under `spec/fixtures/card_scanner/`, keyed by manifest `file`.

## Non-Goals

- Art on the photo-picker path. Its margins are thin (median right 340 bits, nearest wrong 350.5) and most of its misses come from the outline (ruled 2026-10-07).
- Detection on live frames (ruled 2026-10-07).
- Weak art choosing a printing, or adding a card the text didn't find.
- A second number for "confident", such as a gap to the nearest artwork of another card. Spec 010 recorded only the nearest wrong artwork, so a gap would be guesswork.
- An admin interface for art matching, or a rake task only for the art build.
- Building on boot.
- Changing the fingerprint's settings, or building from `normal` images.
- A measurement on unseen cards. None are at hand.
- A pass threshold for any rate.

## Success Criteria

- With art off, the scanner, the ranking and the catalog refresh behave as they do today. Specs prove that nothing is fetched or built, the index route answers 404, and the page has no index URL or status line.
- With art on, a refresh enqueues the build. The build fetches with Scryfall manners, resumes after an interruption without fetching an image twice, falls back to another printing's image, and writes a versioned index served gzipped and immutable. `catalog:status[mtg]` reports its progress and result. All of this is covered by specs with stubbed HTTP.
- The shipped Ruby build and browser fingerprint agree to 0 bits on spec 010's 134 artworks before the development index is used.
- The ranking puts a confident art match first over a disagreeing strong name and collector line, applies weak art only as a tie-break, ignores invalid art, and records the deciding tier. Each rule has its own spec, and the existing text-only ranking specs pass unchanged.
- No frame, strip, photo or fingerprint leaves the device in normal use. A request spec shows the reading accepts only text and artwork ids with distances.
- The closing measurement reports the outcome for each of the 35 cards, the rates against spec 009 and spec 010, the phone times, and any confident wrong match, with its bias stated. The expectation, not a threshold, is more than 30 of 35 right first time.
- `bin/ci` passes at every commit.

## Architecture Decisions

This brainstorm makes no new architecture decision. The two that shape spec 011 were decided after spec 010 and are Accepted:

- [ADR 0006: Fingerprint the artwork and build the art index from the catalog's images](../../adr/0006-art-fingerprint-and-index.md) — Accepted 2026-10-07. The index is built on the server, in a background job after the catalog refresh, from Scryfall's `small` images at the settings frozen at `39cdc6e`. It falls back to another printing's image of the same artwork. The decoder is the plan's choice, gated on 0-bit agreement with the browser.
- [ADR 0007: Search the art index in the browser](../../adr/0007-art-search-in-the-browser.md) — Accepted 2026-10-07. The scanner page downloads the index from the app and searches it on the device: 19 ms median on the iPhone, against about 2.7 s per scan for a Ruby search on the server, with no fingerprint leaving the device.

[ADR 0004](../../adr/0004-card-recognition-in-the-browser.md) (Accepted) still holds: collectors' pictures are fingerprinted on the device.

Decisions kept inline, with the reasons:

- **The ranking order (art above the name).** This is a maintainer ruling. The spec records it as an acceptance criterion, as spec 009 AC-5.5 recorded the current rule.
- **The decoder.** ADR 0006 leaves it to the plan, which may write an ADR if the choice adds a dependency.
- **The index file's format and naming** follow ADR 0006 and ADR 0007's Consequences.

## Out of Scope

- **Art on the photo path,** as evidence behind a distance margin (spec 010 recommendation 3). This is for a later spec.
- **Detection within a region around the guide on live frames,** or re-tuning `minSeparation` for live framing.
- **Choosing a printing by frame era,** and foil detection. A foil's artwork is its printing's, so finish stays a tap.
- **Other languages,** beyond what the shared `illustration_id` already gives non-English printings.
- **A published third-party art-hash index, or a server-side search** (ADR 0006 Option B, ADR 0007 Options B and C).
- **Unseen-card measurement of art,** until a new pile is at hand.
