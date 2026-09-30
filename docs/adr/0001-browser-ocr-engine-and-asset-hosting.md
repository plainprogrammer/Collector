# 0001: Self-host Tesseract.js 7 for in-browser OCR

## Status

Proposed

## Context

The card scanner reads a card's name bar and collector line in the collector's browser, so photos never leave the device (spec 005, FR-1, FR-2). The engine, its worker, its WebAssembly core and its language data must come from the app's own origin, not a CDN, under a strict Content Security Policy.

Phase 0 tested Tesseract.js served this way from a spike server ([research.md](../specs/005-card-scanner-phase-0/research.md), Sections 2, 3 and 6):

- Versions: `tesseract.js` 7.0.0, `tesseract.js-core` 7.0.0 and `@tesseract.js-data/eng` 1.0.0 (`4.0.0_best_int`), downloaded from the npm registry with `curl`, no Node toolchain. Core 7.0.0 must be pinned explicitly: at planning, the core package's `latest` tag still pointed to 6.1.2.
- On the maintainer's iPhone (iOS 18.7, Brave on WebKit), a cold load downloaded 7,031,507 bytes in 8 requests and was ready 528 ms after page load. A warm load fetched 1,055 bytes (the engine, core and language data weren't requested) and was ready in 313 ms. Per-photo recognition of both strips: median 626 ms, slowest 1,911 ms (n=11, cold and warm pooled).
- The engine downloads one core build per device (`simd-lstm` on the iPhone, 3,899,472 bytes; `relaxedsimd-lstm` in desktop Firefox 156). The core directory holds six builds, from 3.9 to 4.7 MB each.
- The policy `default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self'; report-uri /csp-report` produced 0 violation reports, and the cold iPhone run succeeded, so no other host was needed. Without `'wasm-unsafe-eval'` the engine can't compile.
- Files were served from a version-pinned path (`/ocr/v7.0.0/`) with `cache-control: public, max-age=31536000, immutable`, and any revalidation answered `304` with no body.

Accuracy is a separate problem (52% of photos had the card in the top 3, n=50) and is caused by how strips are framed, not by the engine (research.md, Section 3).

## Decision

Use Tesseract.js 7.0.0 with `tesseract.js-core` 7.0.0 and the `eng` `4.0.0_best_int` language data, self-hosted by the app:

- Host the library, worker, all core builds and the language data under a path that carries the version. The proposed Phase 1 location is `public/ocr/v7.0.0/`, outside Propshaft, because Tesseract builds the core and language file names itself. Phase 0 added nothing to `public/`.
- Serve them with a long-lived `immutable` cache header, and answer revalidation with `304`.
- Load the engine only on the scanner page, never site-wide.
- Give the scanner page a CSP whose sources are only `'self'`, `blob:` for the worker and `'wasm-unsafe-eval'` for compiling the engine.
- Pin the exact versions; upgrading is a new version path, so cached files never go stale.

## Consequences

- Photos stay on the device, and the page makes no third-party requests.
- The first scan on a device costs about 7 MB; later visits cost about 1 KB. Self-hosters serve those files themselves.
- 28,904,967 bytes of engine files (the library, the worker, six core builds and the language data; the sum of the measured sizes) would live in the repository or be fetched at build time. Phase 1's plan chooses which.
- `'wasm-unsafe-eval'` on the scanner page widens its policy slightly compared with the rest of the app. Keeping the engine off other pages limits that.
- Upgrades are manual: fetch the new versions, add a new version path, update the page's paths, re-measure.
- The engine doesn't fix accuracy. Phase 1's capture method (a live guide overlay, research.md Section 8) decides whether the scanner is good enough.
