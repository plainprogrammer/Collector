# 0006: Fingerprint the artwork and build the art index from the catalog's images

## Status

Accepted (2026-10-07, maintainer ruling on the spec 010 findings, [research.md](../specs/010-card-scanner-art-spike/research.md) §8: spec 011 builds the index as below, with the image fallback added to the Decision). Proposed 2026-10-03 from the spec 008 findings.

**Date:** 2026-10-03
**Feature:** 008-card-scanner-phase-2-spike

## Context

Art matching identifies a card by comparing a fingerprint of the artwork in the collector's picture with an index holding one fingerprint per artwork in the catalog. Where the text path can't name the card or its printing (a misread name, an older frame with no set code, a faint foil collector line), the artwork can. [ADR 0004](0004-card-recognition-in-the-browser.md) puts the fingerprinting of collectors' pictures in the browser and allows the index to be built on the server, because that work handles catalog data, not collectors' pictures. It left the fingerprint's settings and the index's design to the Phase 2 spike.

The spike ([research.md](../specs/008-card-scanner-phase-2-spike/research.md) §7–§10) used the roadmap's fingerprint: the art box (x 0.14–0.86, y 0.16–0.50 of the straightened card), each of four planes (grey, blue, green, red) resampled to 17×16 by area and compared between horizontal neighbours, 1,024 bits in all, with the query tried at six offsets. The settings were tuned on 52 development photos and frozen at `39cdc6e`. The index was built in Ruby (ImageMagick decodes, pure Ruby fingerprints) from Scryfall's `small` images (146×204), one per artwork, and searched with fingerprints made in the browser. The figures below are from the 47 held-out photos, on the desktop.

| Held out (47) | Full index (50,923 artworks) | 598-artwork subset |
|---|---|---|
| Right artwork first | 33/47 (70.2%) | 34/47 (72.3%) |
| Right artwork first, outline classed found | 20/24 (83.3%) | 21/24 (87.5%) |
| Right card in the text top 3 or right artwork first | 40/47 (85.1%) | 40/47 (85.1%) |
| Text top 3 alone, same photos | 32/47 (68.1%) | 32/47 (68.1%) |
| Median distance: right artwork / nearest wrong | 203 / 346 bits | 211 / 385.5 bits |

| The full index | Value |
|---|---|
| Artworks | 50,923: every one of the catalog's 50,959 artworks with an image (36 art-series artworks have none) |
| Record | 144 bytes: a 16-byte artwork id and a 128-byte fingerprint |
| Size | 7,332,912 bytes stored, 6,007,929 compressed |
| Images fetched | 50,923 `small` images, 707,955,694 bytes, 9,448.8 s at one request per 100 ms or slower (measured in two parts) |
| Fingerprinting | 1,066.6 s for 50,923 images (desktop) |

The browser (canvas) and the Ruby build compute the fingerprint with different code, but both implement the same area resampling, and they agreed to 0 bits on 198 `small` and 98 `normal` images. For 14 of the 34 held-out cards whose collector line didn't give the exact printing, the artwork belongs to exactly one printing; the full index put it first for 10 of them. What the full index lost against the subset was weak matches only (right-artwork distance 330 bits or more). Nothing was measured on a phone.

## Options considered

### Option A: The spike's fingerprint, with an index the app builds from Scryfall's small images

**Pros:**
- Measured: 33/47 held out against the full index, with exact agreement between the browser and the Ruby build.
- The `small` image is the cheapest Scryfall offers that the spike measured: about 13,900 bytes per artwork, about 708 MB for the whole catalog.
- Built from the catalog's own source, keyed by the same artwork ids, refreshed with it. Nothing outside the project defines the fingerprint.

**Cons:**
- Every instance fetches about 50,900 images (about 2.6 hours at the throttled rate) for its first build, then each new set's artworks.
- The build needs an image decoder the app's image lacks: ImageMagick (4 packages, 3,177 KiB on the app's runtime image) or `ruby-vips` with `ffi` (libvips is already installed; `ffi` isn't in `Gemfile.lock`). A `ruby-vips` build's agreement with the browser is unmeasured.
- The catalog needs an artwork id, which it doesn't store today.

### Option B: A published art-hash index

**Pros:**
- No image fetch and no fingerprinting on the instance.

**Cons:**
- Not consumed or compared in the spike: its accuracy here, its agreement with fingerprints made in the browser, and its licence and update schedule are all unknown.
- A published index built with another tool's resampling may not agree with the browser's fingerprint; the spike's index agrees exactly because both sides implement the same resampling.
- The instance would depend on a third party to keep the index current with new sets.

### Option C: The same fingerprint from Scryfall's normal images

**Pros:**
- More detail per artwork. The browser and Ruby agreed to 0 bits on 98 `normal` images too.

**Cons:**
- About 95,900 bytes per image (98 corpus images, 9,393,700 bytes), so about 4.9 GB for the catalog (arithmetic, not measured), against about 708 MB for `small`.
- No index was built from `normal` images, so any gain in accuracy is unmeasured.

## Decision

**Accepted: Option A.** Spec 011 builds the art index on the server from Scryfall's `small` images, with the fingerprint settings frozen at `39cdc6e` (`spikes/card_scanner/phase2/settings.json`):

- **Fingerprint:** the art box x 0.14–0.86, y 0.16–0.50 of the straightened card (1008×1408); four planes (grey, blue, green, red) area-resampled to 17×16, each cell the mean of the source pixels it covers with fractional edge weights; horizontal neighbour differences, 4 × 256 = 1,024 bits. A query tries six offsets, (0, 0), (±0.02, 0), (0, ±0.02) and the unshifted box inset by 0.03, and keeps each artwork's smallest Hamming distance.
- **Index:** one record per artwork, a 16-byte artwork id and the 128-byte fingerprint (144 bytes), after a 28-byte header (`CART`, format version, the settings digest, the record count), compressed, and named by catalog version, settings digest and record count. The image for each artwork is the front face's `small` image of its oldest English card printing that has one (release date, then set code, then number; maintainer ruling 2026-10-07, replacing "first printing in the bulk file's order", which the app doesn't keep after a refresh). Artworks with no image on any printing are left out.
- **Build:** in a background job after the catalog refresh, never during a request. Images are fetched with the manners the spike used (a descriptive `User-Agent` and `Accept`, at least 100 ms between requests, timeouts, back-off on 429 and 5xx), cached in `storage/catalog/mtg/` beside the bulk downloads, and never fetched twice; a refresh fetches only new artworks. The decoder is ImageMagick or `ruby-vips`, decided in spec 011's plan; whichever is chosen must show the same 0-bit agreement with the browser before the index is used.
- **Catalog:** the artwork id joins the catalog in the MTG extension (it is Scryfall's `illustration_id`), not in the collectible-agnostic core.

Option B is rejected because nothing about it was measured and it would tie the scanner to a third party's resampling and schedule. Option C costs about seven times the fetch for no measured gain.

## Consequences

- A self-hosted instance spends about 2.6 hours and about 700 MB of downloads building its first index, in the background, and fetches each new set's artworks on later refreshes. The scanner's art matching isn't available until the first build finishes.
- `storage/` grows by the cached images (about 708 MB) and the index (about 7.3 MB).
- The app's image gains ImageMagick (about 3.2 MB installed) or the `ffi` gem; the choice is spec 011's.
- The catalog gains an artwork id, a schema change in the MTG extension. The migration must be safe to run unattended, like every other.
- The fingerprint's settings become part of the index's format: changing any of them means rebuilding every instance's index, so the index records the settings it was built with.
- Another printing's artwork of the same card can rank first (the bulk file gives some printings of the same card their own artwork ids; for one held-out photo the nearest artwork, at 163 bits, was another printing's of the same card), so the scanner should group art results by card before showing them.
- **Spec 010's figures** ([research.md](../specs/010-card-scanner-art-spike/research.md) §2, §5, §6), against bulk `default-cards-20261003210542` at the same frozen settings:
  - **Rebuild cost:** 50,924 artworks (of 50,960; 36 have no small image), 50,924 images fetched, 707,970,856 bytes in 9,467.4 s (estimate 707,496,912 bytes, 2.623 h); fingerprinting 2,901.1 s on the desktop; 7,333,056 bytes stored, 6,008,050 gzip.
  - **Agreement:** 0 bits median and largest between the build and the browser, n=134 (34 sitting artworks and 100 others).
  - **Live frames and photos,** spec 009's 35 sitting cards captured live on the iPhone, replayed on the desktop against the full index: right artwork first 33/35 from the guide-box crop (median right 189 bits, nearest wrong 341); 5/35 when the shipped detector runs on the whole live frame (its `minSeparation` 0.65 exceeds the card's 0.596 share of the frame; 10 frames without an outline); 20/35 on the unguided photos through the detector (median right 340, nearest wrong 350.5). Text top 3 or art first: 35/35 guide, 31/35 detected, 34/35 photo, against 31/35 for the text alone.
  - **Printings:** art named the exact printing for 4 of the 14 printings spec 009's text missed (guide path); the other ten share their artwork with another printing. Of spec 009's five misses and corrections the guide path put the right artwork first for all five, but only Past in Flames (WHO 565) has an artwork of its own.
- **Spec 011's shipped figures** ([research.md](../specs/011-card-scanner-art-matching/research.md) §2–§3, measured 2026-10-08), the shipped job on the development catalog `default-cards-20261008210545`, settings digest `aa574ad30218cd69`:
  - **Decoder:** ImageMagick's command line (`magick`), [ADR 0012](0012-decode-art-images-with-imagemagick.md): 7.1.2-32 on the desktop, 7.1.1-43 in the amd64 production image.
  - **Build cost:** 48,734 artworks indexed, 0 without an image, 0 failed; the image cache was seeded from spec 010's, so the job fetched 51 images. 1,743.9 s from start to finish (about 29 min), almost all fingerprinting; fetch and fingerprint times weren't recorded separately. A first build without a seed still fetches every image (spec 010: about 708 MB, 2.6 h).
  - **Index size:** 7,017,724 bytes stored, 5,742,930 bytes gzip.
  - **Agreement:** 0 bits median and largest between the shipped build and the shipped page, n=134; the image's decoder gave fingerprints identical to the desktop's on all 134.
- Where the index is searched is [ADR 0007](0007-art-search-in-the-browser.md).
