# Feature 008: Card Scanner Phase 2 Spike — Findings

**Spec:** [spec.md](spec.md) | **Plan:** [plan.md](plan.md)
**Branch:** `008-card-scanner-phase-2-spike`

## Fetch estimate and the maintainer's decision

The art index needs one image per artwork. This section estimates the cost of fetching all of them from Scryfall's image host, before any full fetch (AC-4.2). The full fetch waits for the maintainer's approval.

**Bulk file.** `default-cards-20261002210553`, the file the app's catalog refresh downloaded.

**Artworks (AC-4.1).** `artworks.rb` keeps the entries the catalog imports: `lang` en, not digital, `"paper"` in `games`.

| Count | Value |
|---|---|
| Entries | 106,697 |
| Entries with an artwork id (front face) | 105,934 |
| Entries without an artwork id | 763 |
| Distinct artworks | 50,959 |

The first printing in the bulk file's order stands for each artwork, and its front-face image is the one fetched. 36 of the 50,959 artworks have no image URL in the bulk file (art-series printings). The fetcher lists them as failed and makes no request for them.

**Corpus artworks, fetched first (AC-4.3).** The 99 corpus photos show 98 distinct printings with 98 distinct artworks. These are needed whether or not the full fetch is approved, so they were fetched first, in both sizes. This also means the 500-artwork sample below is drawn from the artworks not yet cached, so it is a random sample of the remainder.

| Size | Fetched | Bytes | Seconds | Failed |
|---|---|---|---|---|
| `small` (146×204) | 98 | 1,304,453 | 18.3 | 0 of 98 |
| `normal` (488×680) | 98 | 9,393,700 | 24.3 | 0 of 98 |

**Estimate (AC-4.2).** `fetch_art.rb --size small --mode estimate`: a random sample of 500 uncached artworks, seed `20261003`, fetched at the throttled rate (at least 100 ms between requests, 2026-10-03).

| Figure | Value |
|---|---|
| Sample | 500 artworks, `small` size |
| Fetched | 500 of 500 |
| Failed | 0 of 500 |
| Bytes fetched | 6,965,982 |
| Time | 90.0 s |
| Per image | 13,932 bytes and 0.180 s (mean of 500) |
| Remaining images (not yet cached) | 50,361 |
| Remaining bytes (extrapolated from 500) | 701,627,639 (about 702 MB) |
| Remaining time (extrapolated from 500) | 2.52 hours |

The 50,361 remaining images include the 36 artworks without an image URL, which will fail without a request. The full fetch would take about 50,361 requests to `cards.scryfall.io`. A background task stops after 2 hours, so it would run in chunks of 90 minutes' worth: `floor(5400 / 0.180)` = 30,006 images per chunk, so two chunks. The cache makes it resumable; nothing is fetched twice.

Decision (maintainer, 2026-10-03): the full fetch was declined. The index covers a subset containing the artwork of all 99 corpus cards: the 98 corpus artworks plus the 500 sampled, 598 in all (AC-4.3). Every art-matching rate in these findings is measured against that subset of 598 artworks, not the catalog's 50,959.
