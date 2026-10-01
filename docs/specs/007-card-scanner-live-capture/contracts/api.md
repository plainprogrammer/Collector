# API Contracts: Card Scanner Phase 1 — Live Capture and Re-measure

All endpoints answer HTML or Turbo Streams for the app's own pages; none is a public API.

## GET /scanner

**Purpose:** The scanner page.
**Spec requirement:** FR-1, Stories 1–4.

### Request

Signed-in session cookie. No parameters.

### Response (200 OK)

HTML. Headers: `Content-Security-Policy` with `default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'nonce-<per request>'; worker-src 'self' blob:; connect-src 'self'; img-src 'self' data: blob: https://scryfall.com https://cards.scryfall.io https://svgs.scryfall.io; style-src 'self' 'unsafe-inline'; font-src 'self'; object-src 'none'; frame-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'self'`. Head: `turbo-visit-control: reload`, `turbo-cache-control: no-cache`, `<script src="/ocr/v7.0.0/tesseract.min.js" defer>`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 302 | Not signed in | Redirect to `/session/new` |

## POST /scanner/readings

**Purpose:** Turn the text read off a card into what the page shows.
**Spec requirement:** FR-3, FR-4, Story 3.

### Request

`multipart/form-data` or form-encoded; `Accept: text/vnd.turbo-stream.html`; `X-CSRF-Token`.

```json
{
  "reading[name_text]": "string, ≤ 2,000 characters — the name strip's OCR text",
  "reading[collector_text]": "string, ≤ 2,000 characters — the collector strip's OCR text"
}
```

### Response (200 OK)

`<turbo-stream action="update" target="scanner_result">` containing `scanners/_result`: the read text, parsed set, number and language, the collector-line outcome (Matched one printing | No printing | Several printings | Not read), and up to 3 candidate tiles (no add button) — or "The card catalog isn't ready yet." / "Nothing could be read."

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 302 | Session ended | Redirect to `/session/new` (the page fetches with `redirect: "manual"` and asks the collector to sign in again) |
| 422 | Text over 2,000 characters | Turbo Stream updating `scanner_result` with "That reading was too long to use…" |

## GET /ocr/v7.0.0/*path

**Purpose:** The self-hosted OCR engine.
**Spec requirement:** FR-3, AC-2.2, ADR 0001.

### Request

`path` ∈ `tesseract.min.js`, `worker.min.js`, `core/tesseract-core-{lstm,simd-lstm,relaxedsimd-lstm}.wasm.js`, `lang/eng.traineddata.gz`. Optional `If-None-Match` / `If-Modified-Since`. No sign-in.

### Response (200 OK)

The file (`text/javascript` or `application/gzip`), `Cache-Control: max-age=31536000, public, immutable`, `ETag`, `Last-Modified`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 304 | Either conditional header matches | Empty |
| 404 | Any other version or path | Empty |

## Measurement mode (development only)

**Purpose:** Record live captures of known cards and replay them (Story 5).
**Spec requirement:** FR-6, AC-5.1–AC-5.6.

### Request

- `GET /scanner/measurement` — the scanner with the manifest panel (signed in).
- `POST /scanner/measurement/captures` — `capture[file]` (a manifest `file`), `capture[name_text]`, `capture[collector_text]`, `capture[ms]`, `capture[user_agent]`, `capture[name_strip]` and `capture[collector_strip]` (PNG, ≤ 5 MB each); signed in.
- `POST /scanner/measurement/skips` — `file`; signed in.
- `GET /scanner/measurement/replay?label=<[\w-]{1,40}>` and `POST /scanner/measurement/replay` (`{ "label": …, "results": [ { "file", "name_text", "collector_text" } ] }`) — local requests only, no sign-in.
- `GET /scanner/measurement/strips/:file?strip=name|collector` — the measured capture's strip; local requests only.

### Response (200 OK)

Captures and skips: `<turbo-stream action="replace" target="measurement_panel">` with the next row selected and a notice ("Stored IMG_1.jpeg as the measured capture." / "as a retake." / "Skipped IMG_2.jpeg."). Replay POST: `204`. Strips: `image/png`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | Measurement mode off (every route); unknown manifest row; replay or strip request from another machine; bad label | Empty |
| 422 | A strip that isn't a PNG ≤ 5 MB, or text over 2,000 characters (panel with the message); a malformed manifest | Turbo Stream / empty |
