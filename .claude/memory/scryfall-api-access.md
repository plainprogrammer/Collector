---
name: scryfall-api-access
description: scryfall.com docs 403 to WebFetch but load with curl + the app's User-Agent; rate limits (api only, *.scryfall.io none); bulk file facts
metadata:
  type: reference
---

- `WebFetch` on scryfall.com documentation pages returns HTTP 403, but the pages load with `curl -s -A "Collector/1.0 (+https://github.com/plainprogrammer/Collector)" <url>`; strip tags with `sed 's/<[^>]*>//g'` (2026-11-06, spec 043). The API itself works with curl plus `User-Agent` and `Accept: application/json` headers: `https://api.scryfall.com/bulk-data`, `/sets`, `/cards/...`.
- Rate limits (`https://scryfall.com/docs/api/rate-limits`, read 2026-11-06): `api.scryfall.com` allows 10 requests a second, 2 a second for `/cards/search`, `/cards/named`, `/cards/random` and `/cards/collection`, 10 a minute for `/cards/manifest`. "The direct file origins located at `*.scryfall.io` do not have rate limits" (images on `cards.scryfall.io`, bulk files on `data.scryfall.io`). A 429 limits access for 30 seconds; continuing may get the app banned.
- Bulk files are listed at `/bulk-data` with `jsonl_download_uri` and `compressed_size`. They are gzip-compressed JSON Lines served as `application/gzip` with no Content-Encoding; `content-length` equals `compressed_size`. As of 2026-09-29: `default_cards` ~79 MB, `all_cards` ~393 MB. As of 2026-11-13: `default_cards` ~81 MB (120,063 lines), `all_cards` ~408 MB (551,935 lines); a Ruby stdlib script streams both in about 2 minutes on the dev machine.
- What the bulk `prices` carry for non-English printings (no price of their own when an English printing of the same set and number exists; no `eur_etched` key) is in research 083, `docs/specs/083-non-english-printing-prices/research.md`, with its counting script.
- `/sets` returns every set in one page (~1,050 sets).
- Multi-face localized cards carry `printed_name` and `image_uris` only on `card_faces[]`.

**How to apply:** For Scryfall research, read docs pages and query the API with curl, never WebFetch. Cite the rate-limits page before reasoning about whether a host can answer 429. The adapter is `MTG::Scryfall::Source` (`app/models/mtg/scryfall/`). Related: [[sdd-review-model-choice]].
