# Research 083: Prices on Non-English Printings

**Status:** Draft: research plan, findings pending
**Date:** 2026-11-13
**Issue:** [#361](https://github.com/plainprogrammer/Collector/issues/361)
**Roadmap:** the [prices lane](../../roadmap.md#prices-lane), first candidate; the [price data design](../../superpowers/specs/2026-11-13-price-data-design.md)'s open question 1
**Before:** [#364](https://github.com/plainprogrammer/Collector/issues/364) (the price source contract) is specified after the ruling here

This is a research note with no spec or plan, as [research 016](../016-scryfall-hosting-terms/research.md) was. It counts what Scryfall's bulk file carries as prices for printings in languages other than English, Japanese first, and sets out what such a printing could show. It writes no production code. The counting script is kept beside this note so the numbers can be reproduced.

## Questions

1. Does a non-English card object in the bulk file carry a `prices` object of its own?
2. How often is each of its prices empty, per finish (nonfoil, foil, etched) and currency (USD, EUR; MTGO tix for reference), per language?
3. Where a non-English printing has an English printing of the same set and collector number, do their prices differ, or is one a copy of the other? Do they share the marketplace ids (`tcgplayer_id`, `cardmarket_id`) the prices come from?
4. Does the file the catalog reads matter? An English-only instance reads `default_cards`, an instance with another language reads `all_cards` (spec 002 FR-3, [catalog operations](../../architecture/catalog-operations.md)); the price refresh reads the same file ([design](../../superpowers/specs/2026-11-13-price-data-design.md), "The daily refresh"). Do the two files carry the same prices for the same card id?

## Method

**Data.** Scryfall's bulk-data index, fetched once from `api.scryfall.com/bulk-data` with the app's User-Agent, and the two files it lists, downloaded from `data.scryfall.io` (not rate limited) outside the repository and never committed:

| File | `updated_at` | Compressed bytes |
|---|---|---|
| `all-cards-20261113102214.jsonl.gz` | 2026-11-13T10:22:14.677+00:00 | 407,728,287 |
| `default-cards-20261113100623.jsonl.gz` | 2026-11-13T10:06:23.955+00:00 | 81,144,238 |

**Population.** The printings the catalog would hold and the price refresh would match: paper printings only, the test `MTG::Scryfall::Mapper.paper?` applies (`digital` false and `games` includes `paper`). Counts over every object, digital included, are given beside them for reference.

**Counts, by the script [`count_prices.rb`](count_prices.rb)** (Ruby standard library only; it streams the gzip file line by line, as `MTG::Scryfall::Source#each_entry` does, and prints Markdown tables):

1. Per language: card objects; objects with a `prices` key; objects whose prices are all empty.
2. Per language, finish and currency: of the printings whose `finishes` list that finish, how many carry a price in that currency (`usd`/`eur` for nonfoil, `usd_foil`/`eur_foil` for foil, `usd_etched`/`eur_etched` for etched). A finish the printing doesn't have isn't counted as empty.
3. Per language, non-English only: printings paired with the English printing of the same set code and collector number, and printings with no such English printing. For each pair and each price: both empty, equal, different, priced only in English, priced only in the other language. For each pair: whether `tcgplayer_id` and `cardmarket_id` are present and equal to the English printing's.
4. Up to ten example pairs per outcome, with set, number and both prices, so a reader can check them on scryfall.com.
5. For card ids in both files: whether the `prices` objects are identical. And the non-English printings in `default_cards` (a card printed only in another language), which an English-only catalog leaves out.

**Reproduce:** `ruby docs/specs/083-non-english-printing-prices/count_prices.rb ALL_CARDS.jsonl.gz DEFAULT_CARDS.jsonl.gz`. The output of the run reported here is [`counts.md`](counts.md). Prices change daily, so a later file gives other numbers; the shape of the findings is what this note relies on.

**Limits.** One day's file. The note reads what Scryfall publishes, not what TCGplayer or Cardmarket list for a language: a price Scryfall leaves empty may exist on the marketplace. It doesn't ask Scryfall how it fills `prices` for a non-English printing; where the counts suggest a rule, the note says it is inferred.

## Findings

Pending the run.

## Options for what a non-English printing shows

Pending the findings. The options to weigh, at least:

- **A. Its own price only.** Empty when Scryfall leaves it empty; the page says there is no price.
- **B. Its own price, else the English printing's, labelled as the English printing's.** The fallback is worked out when shown, by set and collector number, and stores nothing twice.
- **C. Always the English printing's price, labelled.**
- **D. No price for a non-English printing.**

## Recommendation

Pending the findings.

## The maintainer's ruling

Pending.
