# 0007: Search the art index in the browser

## Status

Proposed (2026-10-03, from the spec 008 findings). The maintainer ruled (2026-10-03) that art matching gets its own spec after spec 009, opt-in per instance. Spec 010 (an art spike) measured the index on the iPhone; spec 011 builds art matching and decides this ADR.

**Date:** 2026-10-03
**Feature:** 008-card-scanner-phase-2-spike

## Context

[ADR 0004](0004-card-recognition-in-the-browser.md) puts card recognition in the browser: the art fingerprint is computed on the collector's device. It left open whether the browser downloads the art index and searches it, or sends the fingerprint for the server to search; both satisfy it, and the Phase 2 spike measured both. [ADR 0006](0006-art-fingerprint-and-index.md) proposes the index: 50,923 artworks, 144 bytes each, built on the server from the catalog's images.

A search compares the photo's six offset fingerprints with every record in the index (six Hamming distances per artwork) and keeps the 10 nearest. The spike timed it both ways against the full index, on the desktop, for the 43 held-out photos with a fingerprint ([research.md](../specs/008-card-scanner-phase-2-spike/research.md) §10):

| Desktop, held out (n=43) | Median | Slowest |
|---|---|---|
| Fingerprint one photo, browser (headless Firefox 156) | 76 ms | 100 ms |
| Search the full index, browser | 77 ms | 93 ms |
| Search the full index, server: Ruby, nothing outside the app's bundle (`ArtIndex#search` over the loaded index; excludes loading it) | 2,667.4 ms | 3,314.7 ms |

Both ranked the same first artwork for 43 of 43 photos (52 of 52 development photos). The index is 7,332,912 bytes stored and 6,007,929 bytes compressed. Nothing was measured on a phone: neither the download, nor the search, nor the memory the index takes in a phone's browser.

Spec 007 FR-3 says the scanner must "send only recognised text to the app in normal use" and must not send "any frame, strip or photo". ADR 0004 records that sending a fingerprint would need FR-3's first line amended.

## Options considered

### Option A: The browser downloads the index and searches it

**Pros:**
- 77 ms median on the desktop, about 35 times faster than the Ruby search.
- No server work per scan; the index is a static file, shared by every tenant (catalog data is global) and cacheable until the next catalog refresh.
- The fingerprint never leaves the device, so the FR-3 amendment ADR 0004 names isn't needed.

**Cons:**
- A 6 MB download (compressed) to the collector's device, again after each catalog refresh that changes the index. Its time on a phone is unmeasured.
- The search's time and memory on a phone are unmeasured.

### Option B: The browser sends the fingerprint; the server searches it in Ruby

**Pros:**
- No index download to the device.
- Nothing outside the app's bundle.

**Cons:**
- 2,667.4 ms median per scan on the desktop server, holding a Puma thread for that long, on an instance every tenant shares.
- The fingerprint leaves the device, so spec 007 FR-3 has to be amended (ADR 0004).
- Every scan becomes server work and a round trip.

### Option C: The server searches with native code or in the database

**Pros:**
- Could be much faster than pure Ruby (not measured), without the download.

**Cons:**
- Not measured. It would need a native extension or a database feature for Hamming distances that the app's SQLite setup doesn't have today.
- The FR-3 amendment and the per-scan server work of Option B still apply.

## Decision

**Proposed: Option A.** The scanner page downloads the art index from the app's own origin and searches it in the browser, with the fingerprint computed there too.

- The index is served as a static, compressed file from the app (so the scanner page's `connect-src 'self'` covers it), fetched only by scanner pages, cached by the browser, and named by the catalog version it was built from, so a refresh that changes the index changes its URL.
- The page loads the index after the scanner starts, so the camera and text recognition don't wait for it; until it has loaded, the scanner works on text alone.
- The page sends the app the artwork ids its search ranked first, so the app can name their printings in the confirm step. It sends no frame, strip, photo or fingerprint.

Option B is rejected: about 2.7 seconds of a Puma thread per scan on the desktop, and the fingerprint would leave the device. Option C is unmeasured and keeps Option B's costs other than speed.

## Consequences

- Spec 007 FR-3's "must not send any frame, strip or photo" holds, and no fingerprint is sent, so the amendment ADR 0004 names isn't needed. The artwork ids the page sends are derived from the picture but aren't recognised text; spec 011 decides whether FR-3's "send only recognised text" covers them or needs a word changed.
- Each collector's device downloads about 6 MB once per catalog change that alters the index, in addition to the text-recognition engine. Spec 010 measured them on the maintainer's iPhone (below); spec 011 decides on them.
- The server does no work per scan for art matching. The index is global catalog data, so it is served without an account and cached without a tenant key.
- The browser's search code and the index's format (ADR 0006) must stay in step; the index records the fingerprint settings it was built with, and the page refuses an index whose settings differ from its own.
- If a phone turns out too slow, the fallback is Option C, measured first; Option B would need FR-3 amended.
- **Spec 010's figures** ([research.md](../specs/010-card-scanner-art-spike/research.md) §3), the full index (50,924 artworks) on the maintainer's iPhone (iOS 26.6.1, Brave, WebKit), served gzip over HTTPS on the LAN:

  | | iPhone, cold | iPhone, warm | Desktop, headless Firefox 156, cold |
  |---|---|---|---|
  | Download | 6,008,050 B gzip in 244 ms | from the browser cache, 11 ms | 51 ms |
  | Ready to search (parse) | 79 ms | 59 ms | 77 ms |
  | Search, median / slowest (n=43) | 19 / 29 ms | 18 / 21 ms | 71 / 110 ms |
  | Fingerprint, median / slowest (n=12) | 14.5 / 29 ms | 14.5 / 19 ms | 54 / 70 ms |

  The phone's first artwork matched the desktop's for 43 of 43 queries, and its fingerprints matched the committed ones to 0 bits. WebKit gives no heap figure; the page holds the decoded index (7,333,056 B), the fingerprint words (6,518,272 B) and 50,924 ids (at most 3,666,528 B), about 17.5 MB, and stayed responsive through 100 searches (longest gap 36 ms). At slower links the cold download would take 1.0 s at 50 Mbit/s, 4.8 s at 10 and 24.0 s at 2 (arithmetic, not measured). The phone searched about 3.7 times faster than the desktop's headless Firefox, so Option C's fallback wasn't needed on this device.
