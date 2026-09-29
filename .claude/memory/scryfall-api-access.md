---
name: scryfall-api-access
description: scryfall.com docs 403 to WebFetch; the API works via curl with a User-Agent; bulk file facts
metadata:
  type: reference
---

- `WebFetch` on scryfall.com documentation pages returns HTTP 403. The API itself works with curl plus `User-Agent` and `Accept: application/json` headers: `https://api.scryfall.com/bulk-data`, `/sets`, `/cards/...`.
- Bulk files are listed at `/bulk-data` with `jsonl_download_uri` and `compressed_size`. They are gzip-compressed JSON Lines served as `application/gzip` with no Content-Encoding; `content-length` equals `compressed_size`. As of 2026-09-29: `default_cards` ~79 MB, `all_cards` ~393 MB.
- `/sets` returns every set in one page (~1,050 sets).
- Multi-face localized cards carry `printed_name` and `image_uris` only on `card_faces[]`.

**How to apply:** For Scryfall research, query the API with curl rather than fetching docs pages. The adapter is `MTG::Scryfall::Source` (`app/models/mtg/scryfall/`). Related: [[sdd-review-model-choice]].
