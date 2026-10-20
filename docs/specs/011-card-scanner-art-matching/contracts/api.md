# API Contracts: Card Scanner — Art Matching on Live Capture

## GET /scanner/art/:name

**Purpose:** The art index the scanner page downloads and searches on the device.
**Spec requirement:** FR-4, Story 4 (AC-4.1–AC-4.4), AC-1.4.

### Request

```json
{
  "name": "string — path segment, the index file's exact name: art-index-<catalog version>-<16 hex settings digest>-<record count>.bin.gz"
}
```

No sign-in, no CSRF (GET, global catalog data). The page fetches it from its own origin (`connect-src 'self'`).

### Response (200 OK)

Headers: `Content-Type: application/octet-stream`, `Content-Encoding: gzip` (always, whatever `Accept-Encoding` says), `Cache-Control: max-age=31536000, public, immutable`, `ETag` (the file name), `Last-Modified`.

Body (after the browser undoes the gzip encoding), big-endian:

```json
{
  "header (28 bytes)": "\"CART\" (4) · format version 1 (1) · 3 zero bytes · settings digest, 16 ASCII hex characters (16) · record count, uint32 (4)",
  "records (144 bytes each, sorted by artwork id)": "artwork id as 16 raw bytes (the UUID's hex without hyphens) · fingerprint, 128 bytes (grey, blue, green, red planes, 32 bytes each, most significant bit first)"
}
```

The page refuses a file whose magic, format version or settings digest differs from its own, or whose length isn't `28 + 144 × count`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 304 | `If-None-Match` or `If-Modified-Since` matches | empty |
| 404 | Art matching off; no index; the name isn't the current or previous index; a malformed name or path | empty |

---

## POST /scanner/readings (existing; one new optional field)

**Purpose:** What the scanner read, ranked into candidates.
**Spec requirement:** FR-3, FR-5, Story 6 (AC-6.1), spec 007 FR-3 as amended.

### Request

`multipart/form-data`, CSRF header, `Accept: text/vnd.turbo-stream.html`:

```json
{
  "reading[name_text]": "string ≤ 2,000 — existing",
  "reading[collector_text]": "string ≤ 2,000 — existing",
  "reading[key]": "32 lowercase hex — existing",
  "reading[artworks][][id]": "optional, repeated with distance, at most 10 pairs, nearest first: lowercase UUID (illustration_id)",
  "reading[artworks][][distance]": "optional: whole number 0–1024, the Hamming distance (smallest over the six offsets)"
}
```

Sent only for a live capture with the index ready and art matching on. Never a frame, strip, photo or fingerprint.

### Response (200 OK)

Turbo Stream `update` of `#scanner_result` (existing), now with the Artwork row, art badge and evidence lines, and the overrule note when they apply (Story 7).

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 422 | Malformed reading key, or text over 2,000 characters (existing) | Turbo Stream with the status message |
| — | A malformed art part (bad id or distance, more than 10, wrong shape) | Not an error: the art part is dropped and the text ranks alone (200) |
| — | Art matching off | The art part is ignored (200) |

---

## GET /scanner/printings (existing; one new optional parameter)

**Purpose:** Other printings of a candidate's card, in a Turbo Frame.
**Spec requirement:** AC-7.5.

### Request

```json
{
  "card": "existing — the identity's external key",
  "key": "existing — the reading key",
  "set": "existing, optional",
  "number": "existing, optional",
  "finish_hint": "existing, optional",
  "artwork": "new, optional — the confident artwork's lowercase UUID; the printings sharing it are listed first"
}
```

### Response (200 OK)

The existing frame; with a valid `artwork`, its printings come first (newest first), then spec 009's order.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| — | `artwork` malformed or unknown | Ignored; spec 009's order (200) |
| 404 | Malformed reading key or unknown card (existing) | empty |
