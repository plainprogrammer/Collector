# API Contracts: Card Scanner — Confirm and Add

Every endpoint is HTML over the wire for the scanner's own page: Turbo Streams or a Turbo Frame, never JSON for the UI. Each needs a signed-in session (otherwise `302` to `/session/new`) and a CSRF token on non-GET requests, and is scoped to `Current.account`.

## POST /scanner/readings (changed)

**Purpose:** what was read, and the candidates with their add buttons.
**Spec requirement:** spec 007 Story 3; spec 009 FR-5, AC-1.1.

### Request

```
reading[name_text]       string, ≤ 2,000 characters
reading[collector_text]  string, ≤ 2,000 characters
reading[key]             string, /\A[0-9a-f]{32}\z/ (new)
```

### Response (200 OK)

`text/vnd.turbo-stream.html`: `update #scanner_result` with what was read and up to 3 candidates. Each candidate has evidence marks, a `form.c-scanner__add` per finish (hidden `entry[printing]`, `entry[finish]` and `entry[reading_key]`; `data-scanner-event="add"`, `data-rank`), an "Other printings" link into `turbo-frame#scanner_printings`, and an empty `turbo-frame#scanner_printings`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 422 | Text over 2,000 characters | stream: "That reading was too long to use…" |
| 422 | Key missing or malformed | stream: "That reading couldn't be used. Capture the card again." |

## POST /scanner/sitting/entries

**Purpose:** add one copy for a reading.
**Spec requirement:** FR-1, Story 1, AC-1.2–AC-1.7, AC-3.1.

### Request

```
entry[printing]     string — the printing's external key
entry[finish]       string — one of the printing's finishes, or "" when it has none listed
entry[reading_key]  string — /\A[0-9a-f]{32}\z/
```

### Response (200 OK)

Turbo Stream with three actions:
- `update #scanner_result`: empty on an add, or the replayed state's message.
- `replace #scanner_sitting`: the list.
- `update #status`: "Added 1 × ‹name› (‹SET› · ‹number›[, ‹finish›]) to your collection." A replay of an undone or changed add gets its message instead ("You added this card, then undid it. Scan it again to add it." or "You added this card, and it has since changed in your collection.").

A repeated key never adds again.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 422 | Key missing or malformed; printing unknown, retired or not a card; finish not offered | stream `update #status`: "That card couldn't be added. Scan it again." |
| 422 | The lot would pass 9,999 | stream `update #status`: "You already have the most copies one lot can hold (9,999)." |
| 400 | No `entry` parameters | Rails' bad request |

## POST /scanner/sitting/entries/:entry_id/undo

**Purpose:** take one add's copy back.
**Spec requirement:** Story 4, AC-4.1–AC-4.4, AC-3.8.

### Request

No body.

### Response (200 OK)

Turbo Stream: `replace #scanner_sitting`, and `update #status` with "Removed 1 × ‹name› (‹SET› · ‹number›[, ‹finish›]) from your collection." Removing the lot ends the session's pending bulk-removal Undo.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | The entry isn't in the current account's open sitting (another account's, or its sitting ended) | empty |
| 422 | Already undone | stream: "That card was already undone." |
| 422 | Its lot was removed or merged away | stream: "That copy has changed in your collection, so it can't be undone here." |

## GET /scanner/sitting/ending/new · POST /scanner/sitting/ending

**Purpose:** confirm and end the sitting.
**Spec requirement:** AC-3.5, AC-3.7.

### Request

POST: no body; the form is non-Turbo.

### Response

- **GET (200):** the confirmation page: "End this sitting?", the count kept, "End sitting" and "Cancel". With no sitting it answers `302` to `/scanner`.
- **POST (303):** to `/scanner`, with `flash[:sitting_summary]` set to the kept count, shown once as "Added N cards in this sitting".

### Error Responses

None beyond the shared ones. With no sitting, POST still answers `303` to `/scanner`, with no summary.

## GET /scanner/printings

**Purpose:** "Other printings" for a candidate.
**Spec requirement:** Story 2, AC-2.2–AC-2.6.

### Request

```
card         string — the identity's external key (required)
key          string — the reading key (required)
set          string — the read set code (optional)
number       string — the read collector number (optional)
finish_hint  string — "foil" when the reading suggested it (optional)
```

### Response (200 OK)

`turbo-frame#scanner_printings` (turbo-rails' frame layout, so no `turbo-visit-control`): the card's active English printings in AC-2.3's order. Each is a `c-list` row with set · number, set name, release date, and add forms with `data-rank="other"`. Twenty show; the rest sit in `details` ("Show N more").

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | `key` or `card` missing | Rails' bad request |
| 404 | Key malformed, or card unknown | empty |

## POST /scanner/measurement/events (development only)

**Purpose:** record an add, Undo or details event for the live sitting.
**Spec requirement:** AC-9.2.

### Request

```
event[kind]         "add" | "undo" | "details"
event[rank]         "1" | "2" | "3" | "other" | ""
event[reading_key]  string — a key a stored capture carries
```

### Response (204 No Content)

Appends `{kind, rank, reading_key, at}` to `<run dir>/<row>/events.jsonl`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | Measurement mode off; unknown key; unknown kind | empty |

## POST /scanner/measurement/captures (changed, development only)

Adds the optional fields `capture[reading_key]`, `capture[outline]` (`live`, `found` or `not_found`), `capture[detect_ms]` and `capture[warp_ms]`. They are stored in `capture-NNN.json`; malformed values are dropped.
