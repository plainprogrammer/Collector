# PRD: Card Scanner Art Spike — The Index on a Phone, and Art on Live Captures

**Date:** 2026-10-05
**Feature:** 010-card-scanner-art-spike

## Problem

Spec 009 shipped the confirm flow. On spec 009's live sitting, 30 of 35 unseen cards ended right first time ([research.md](../009-card-scanner-confirm-flow/research.md) §8). The misses and corrections all share one cause: the collector line gave no usable printing, so the name chose the newest one. This happened for:
- older frames with no set code: IMG_6808 Plains (M10 233) and IMG_6829 Mana Geyser (CNS 147)
- a lost set code: IMG_6821 Pegasus Guardian (CLB 36)
- corrections through Other printings: IMG_6814 Obsidian Fireheart and IMG_6823 Past in Flames

Art matching was proposed for exactly this (spec 008 [research.md](../008-card-scanner-phase-2-spike/research.md) §14). Spec 008 put the right artwork first for 33 of 47 held-out photos against the full index of 50,923 artworks. The maintainer ruled (2026-10-03) that art matching gets its own spec, opt-in per instance, with the index's phone download and search time measured first.

Two things about it are still unmeasured, and both decide how it should be built:

- **The index on a phone.** [ADR 0007](../../adr/0007-art-search-in-the-browser.md) proposes that the browser downloads the index and searches it there:
  - The index is 6,007,929 bytes compressed and 7,332,912 stored.
  - The search took 77 ms median on the desktop, against 2,667 ms for a pure-Ruby server search.
  - Its download time, search time and memory on the maintainer's iPhone are unknown.
- **Art on live captures.** Spec 008 measured art only on photos the detector had straightened. Live captures, which spec 009's sitting used and which miss in these cases, aren't straightened; the card only roughly fills the guide box. Spec 009 also kept detection off live frames. Whether art works from the guide box, or needs the live frame detected and straightened first, is unknown.

Building art matching (catalog artwork id, the opt-in fetch and index build, search, ranking, UI) before these are measured risks building it on the wrong path. This spike measures both, so the maintainer can rule on spec 011, which builds art matching, and on ADRs 0006 and 0007.

### How the art work is shaped (maintainer rulings, 2026-10-05)

- **Two specs.** Spec 010 is this spike. Spec 011 builds art matching after the maintainer's ruling on the findings.
- **Art runs on both paths, measured first.** Spec 011 targets live captures as well as picked photos, provided this spike's live-frame measurement supports it.
- **The full index is rebuilt** with real fingerprints, rather than synthetic ones or a subset. The fetch waits for the maintainer's approval of a committed estimate, as in spec 008.
- **The same 35 cards** (spec 009's pile, IMG_6806–IMG_6840) are captured live again, so the results compare directly with spec 009's text-only sitting.
- **Live-frame data comes from the app's development-only measurement mode** (Approach A). The phone captures; the desktop fingerprints and searches.

## Users & Context

**Primary user:** the maintainer, who captures the cards on the iPhone, reads the findings, and rules on spec 011's scope and on ADRs 0006 and 0007.

**Secondary users:** Claude Code sessions that write spec 011 from the findings. Collectors and self-hosters aren't affected: nothing they use or run changes in normal use.

**What the spike works with:**

- **Spec 008's art tools,** committed under `spikes/card_scanner/phase2/`:
  - the bulk-artwork reader, the throttled fetcher and the index builder
  - the Ruby fingerprint, and the browser `fingerprint.js` and `search.js`
  - settings frozen at `39cdc6e`

  The browser and Ruby fingerprints agreed to 0 bits on 198 images. The spec 008 index and the cached artwork images are gone (they lived in a removed worktree), so the index is rebuilt.
- **The development catalog,** refreshed for spec 009 (`default-cards-20261003210542`, 106,698 printings), and its Scryfall bulk file, which carries each card's `illustration_id` and `small` image URL. The catalog doesn't store artwork ids.
- **Spec 009's 35-card pile,** whose manifest and ground truth (35 cards, 8 foils, era overrides) are at `~/card-scanner-corpus/phase2-sitting/`, with one unguided photo of each card beside them. Spec 009's text-only results on the same cards are committed as fixtures (`phase2_sitting_*`).
- **The app's development-only measurement mode** (specs 007 and 009). It captures live on the iPhone over HTTPS from the dev machine, stores strips, reading keys, outlines and timings outside the repo, and serves stored photos to desktop replays. It never runs in production.
- **The shipped detector** (`app/javascript/scanner/detector.js`, ADR 0005), which matches the spike's on all 99 photos.
- **The maintainer's iPhone,** running Brave (WebKit), on the dev machine's LAN (`192.168.1.76`), with the self-signed certificate from spec 007 already trusted.

## Goals

1. **Measure the index on the iPhone.** A spike page served over HTTPS from the dev machine loads the full index on the phone. It reports:
   - the bytes transferred and the download time on the LAN, with the times those bytes would take at slower connection speeds (arithmetic, labelled as such)
   - the time to make the index ready to search
   - the search time, median and slowest, over a fixed set of query fingerprints
   - the time to fingerprint a straightened card on the phone. The page uses straightened cards the desktop replay produced from the stored frames, and serves them to the phone.
   - **memory:** WebKit exposes no heap measure, so the index's in-memory size and whether the page stays responsive through repeated searches
2. **Measure art on live captures.** The 35 cards are captured live once each on the iPhone, with the measurement mode storing each full frame on the dev machine.
   - **Frames are stored losslessly (PNG),** so the fingerprint isn't perturbed. The frame size cap is raised (or separate from the strips' 5 MB cap) to fit a full camera frame.
   - **The guide rect the phone used** (x, y, width, height in frame pixels) is stored beside each frame, so the guide-box fingerprint is exactly what the phone would have computed.
   - **Retakes:** as in spec 007's protocol, a retake is allowed only when the first capture is unusable, and the first capture is the one scored. Retakes are reported. On the desktop each frame is fingerprinted two ways, from the guide box and from the detected and straightened card, and searched against the full index.
3. **Measure art on the same cards' unguided photos,** through detection on the desktop, for a photo-path comparison.
4. **Report against spec 009's text-only sitting on the same cards.** For each path (live guide box, live detected, photos):
   - right artwork first, and right card first by art
   - the right card in the text top 3 or first by art
   - how often art identifies the exact printing where the text didn't
   - spec 009's misses and corrections, named individually

   Every rate carries its sample size. The headline comparison takes the cards' text results from spec 009's committed fixtures. A secondary figure combines art with the text read in the same new capture, a like-for-like number for spec 011's ranking design.
5. **Rebuild the full art index** at the frozen fingerprint settings against the current catalog, after committing an estimate (artworks, bytes, hours) and getting the maintainer's approval. Cached images live outside the repo and worktrees, in `~/card-scanner-corpus/art-cache/`. Spec 008's fetcher and index builder hard-code their cache under the repo's `tmp/`, so they gain a cache-directory setting. Their bulk-file reader takes this worktree's newest bulk file, which should be spec 009's (`default-cards-20261003210542`); the plan checks that.
6. **End with recommendations** for spec 011 (which paths get art, how art joins the ranking) and updates to ADRs 0006 and 0007 with the phone figures. The same edit corrects the ADRs' spec references, which predate the 2026-10-03 ruling: they say spec 009 builds the index and measures the phone, where now spec 010 measures and spec 011 builds and decides. No pass threshold is set; the maintainer rules.

## Non-Goals

- Anything collectors use: no catalog artwork id, no opt-in setting, no index build in the catalog refresh, no art in the ranking, and no UI. That is spec 011.
- The index build's decoder choice for production (ImageMagick or `ruby-vips`, open in ADR 0006). The spike reuses spec 008's ImageMagick-based tools.
- Tuning the fingerprint. Its settings stay frozen at `39cdc6e`; this spike measures them on new paths.
- Detection on live frames as a product feature. The spike only measures it offline.
- Measuring on other phones or browsers, or over the internet rather than the LAN.
- A pass threshold for any figure.

## Success Criteria

- The findings report every Goal 1 figure for the maintainer's iPhone, with the device and browser, the index's size and the number of searches.
- The findings report Goal 4's rates for the live guide-box, live detected and photo paths on the 35 cards. Each has its sample size and the comparison with spec 009's text-only results. Spec 009's five misses and corrections are named with their art outcome.
- The full index was rebuilt only after the maintainer approved the committed estimate. Its record count, size and build time are reported, and the browser and Ruby fingerprints still agree (re-checked on a sample).
- Nothing in normal use changes:
  - The measurement mode's frame storage is development-only, behind the existing measurement setting, and covered by a test that it's off in production and test.
  - No image, frame or index is committed.
  - `bin/ci` passes at every commit.
- The findings end with recommendations for spec 011 and for ADRs 0006 and 0007, and set no pass threshold.

## Architecture Decisions

This spike makes no new architecture decision. Its apparatus (the phone timing page, the frame storage in measurement mode, the replay scripts) is throwaway, so it gets no ADR; why it's built this way is recorded here.

It informs two Proposed decisions, which spec 011 accepts or revises after the maintainer's ruling:

- [ADR 0006: Fingerprint the artwork and build the art index from the catalog's images](../../adr/0006-art-fingerprint-and-index.md) — Proposed. This spike adds the rebuild's cost against the current catalog, and accuracy on live captures.
- [ADR 0007: Search the art index in the browser](../../adr/0007-art-search-in-the-browser.md) — Proposed. This spike adds the phone's download, search time and memory.

[ADR 0004](../../adr/0004-card-recognition-in-the-browser.md) (Accepted) still holds. Collectors' pictures are fingerprinted on the device in normal use. In this spike, frames go to the dev machine only in development measurement mode, as strips did in specs 007 and 009.

## Out of Scope

- Spec 011's build: the catalog artwork id (schema change), the opt-in instance setting, the fetch and index build in the catalog refresh, serving the index, art evidence in `MTG::Reading`'s ranking, grouping art results by card, the spec 007 FR-3 amendment (match results may be sent), and the UI.
- Choosing between ImageMagick and `ruby-vips` for production.
- Foil detection by art. A foil's artwork is the printing's artwork, so finish stays a tap.
- Live alignment feedback, continuous capture, other languages.
