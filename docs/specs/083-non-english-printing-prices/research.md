# Research 083: Prices on Non-English Printings

**Status:** Draft: findings and recommendation, for the maintainer's ruling
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
3. Per language, non-English only: printings paired with the English printing of the same set code and collector number (its **English twin**), and printings with no twin. For each pair and each price: both empty, equal, different, priced only in English, priced only in the other language. For each pair and each finish the non-English printing has: the USD outcome and the EUR outcome together, so an equal pair shows whether it is equal in both currencies or in one (counts section 4a). For each pair: whether `tcgplayer_id` and `cardmarket_id` are present and equal to the twin's.
4. Per language, the printings with no twin, by the reason the file shows (counts section 4b): the set has no English paper printing at all; the English printing of that number isn't paper; the number carries a ★ (and whether the number without it is in English); a plain number the set has no English printing of; a number with another mark. For each reason, how many carry any USD or EUR price, the five most common sets, and whether `default_cards` carries the printing too.
5. Up to ten example pairs per outcome for Japanese and three for another language, with set, number and both prices, so a reader can check them on scryfall.com.
6. For card ids in both files: whether the `prices` objects are identical. And the non-English printings in `default_cards` (a card printed only in another language), which an English-only catalog leaves out.

The counts section numbers below (§1 to §8) are those of [`counts.md`](counts.md).

**Reproduce:** `ruby docs/specs/083-non-english-printing-prices/count_prices.rb ALL_CARDS.jsonl.gz DEFAULT_CARDS.jsonl.gz > counts.md`, with the two files of the table above; it took about two minutes on the dev machine. The output of the run reported here is [`counts.md`](counts.md). Prices change daily, so a later file gives other numbers; the shape of the findings is what this note relies on.

**Limits.** One day's file. The note reads what Scryfall publishes, not what TCGplayer or Cardmarket list for a language: a price Scryfall leaves empty may exist on the marketplace. It doesn't ask Scryfall how it fills `prices` for a non-English printing; where the counts suggest a rule, the note says it is inferred.

## Findings

### Answer

- **Every card object has a `prices` object of its own,** in every language (§1). For a non-English printing it is almost always empty: 97.5% of Japanese paper printings (62,440 of 64,033) have no price at all, and 96.6% to 99.8% of every other major language. English: 5.4%.
- **A non-English printing with an English twin carries no price of its language.** Of 428,442 such printings in ten languages, none has a USD price, none has a `tcgplayer_id`, and where one has a EUR price (5,256 nonfoil, 2,411 foil) it is the twin's price, to the cent, under the twin's `cardmarket_id` (§3, §4, §5). The file holds 12 exceptions in all (§4, §6, §7).
- **A printing with no English twin has prices of its own,** and often: those are separate products, such as the Japanese War of the Spark planeswalkers numbered with a ★ and the Japanese Mystical Archive and Strixhaven printings with numbers of their own (§3, §4b).
- **Equal means equal in EUR only, never in both currencies** (§4a), because no paired non-English printing has a USD price.
- **`default_cards` and `all_cards` carry the same prices for the same card id** (all 120,063 ids, §8). The file decides which printings exist, not what they cost.
- **The file has no `eur_etched` key at all** (§2), in any object. The price data design lists it among the prices; it is five series, not six.

### Japanese

| Japanese paper printings (§1, §3, §4b) | Count | Nonfoil USD / EUR priced | Foil USD / EUR priced | Etched USD priced |
|---|---|---|---|---|
| All | 64,033 | 0.4% / 2.1% | 0.8% / 1.7% | 9.0% |
| With an English twin | 63,003 | 0.0% / 1.5% | 0.0% / 0.8% | 0.0% |
| No English twin | 1,030 | 30.9% / 46.7% | 90.1% / 97.4% | 100.0% |
| *English, for comparison* | *108,241* | *92.4% / 92.4%* | *92.4% / 92.2%* | *100.0%* |

Shares are of the printings whose `finishes` list that finish (the denominators are in §3). No etched EUR exists in any language (no `eur_etched` key).

- **With an English twin (63,003).** USD: none. EUR: 947 nonfoil and 344 foil prices, every one equal to the twin's (§4); 962 Japanese printings with a twin carry the twin's `cardmarket_id` and none an id of its own (§5). No pair has a USD price on both sides, so no pair is equal in both currencies (§4a: 944 nonfoil pairs are "USD English only, EUR equal", 3 are "USD both empty, EUR equal"; foil 340 and 4). Their English twins are priced as English printings are: `usd` on 61,480 of the 63,003 (§4). The examples with a copied EUR price come from sets such as `ltr`, `ltc`, `40k`, `vow`, `ncc` and `ddk` (§7).
- **No English twin (1,030), by reason (§4b):**

| Reason | Printings | Any USD | Any EUR | Most common sets |
|---|---|---|---|---|
| The set has no English paper printing | 662 | 143 | 263 | `4bb` 378, `bchr` 125, `pwcs` 46, `pmps` 20, `pjjt` 12 |
| A plain number the set has no English printing of | 228 | 225 | 226 | `soa` 130, `sta` 63, `sld` 16, `neo` 10, `iko` 3 |
| A ★ number whose plain number is in English | 74 | 60 | 74 | `pwar` 36, `war` 36, `dd2` 2 |
| A number with another mark | 60 | 43 | 54 | `pmei` 47, `plg24` 6, `plg21` 3 |
| A ★ number whose plain number isn't in English | 6 | 2 | 6 | `pwwk` 2, `pm11`, `proe`, `purl`, `pzen` |

Every Japanese `tcgplayer_id` in the file (512, §1) is on a printing with no English twin. Of the 1,030, `default_cards` carries 652 and lacks 378, as many as the Japanese Foreign Black Border (`4bb`) printings; none of the 378 is priced (§4b, second table).

### The other languages

The same pattern holds for French, German, Spanish, Italian, Simplified and Traditional Chinese, Portuguese, Russian and Korean (§3 to §5): no USD price on any printing with an English twin; a EUR price on 0.2% to 1.7% of them, equal to the twin's and under its `cardmarket_id`. The exceptions, 12 prices of 428,442 pairs:

- 11 Spanish Portal (`por`) printings with a `cardmarket_id` of their own and a EUR price that differs from the English one (median ratio 0.83, §6).
- 1 French printing (`bro` 379) with a EUR price where its English twin has none (§7).

The printings with no twin are mostly language-only sets (§4b): Foreign Black Border (`4bb`, `fbb`), the Renaissance sets (`ren`, `rin`), Salvat (`psal`); and the languages of a few cards (`ph`, `tlh`, `qya`, `dw`, `grc`, `ar`, `he`, `la`, `sa`), every one with no twin.

### The two files

- All 120,063 card ids of `default_cards` are in `all_cards`, with identical `prices` (§8). `default_cards` also carries 2,660 non-English objects, a card's only language (§8), which an English-only catalog leaves out today (spec 002 FR-3): the source keeps only the configured languages.
- The printings with no twin that `all_cards` alone carries are priced only for German (119 of 428) and Portuguese (219 of 375), whose printings with no twin are almost all Foreign Black Border and Renaissance (`fbb`, `ren`, `4bb`); none for Japanese (§4b, second table). For every other printing, `all_cards` adds no price that `default_cards` lacks, since a paired printing's prices are copies.

### Inferred, not confirmed

- Scryfall fills a printing's prices from the marketplace ids on that card object. TCGplayer ids are on English printings and on language-only printings; a non-English printing of an English card has none, so it has no USD. Some non-English printings carry the English printing's `cardmarket_id`, so they show the English printing's EUR (§5). The note didn't ask Scryfall.
- So a non-English printing's EUR, where present, is not a price for that language: it is the same number as the English printing's and can't be told apart from it.

## Options for what a non-English printing shows

A **twin** is the English printing of the same set code and collector number. The catalog always holds English (`MTG::Scryfall::Source#languages` adds `en`), so a twin in the file is a twin in the catalog. A printing with no twin is a product of its own.

| Option | A Japanese printing with a twin shows | A printing with no twin shows | Fair to the data? |
|---|---|---|---|
| **A. Its own prices only** | Nothing on 98.5% of nonfoil and 99.2% of foil; a EUR price on the rest, presented as its own though it is the English one | Its own prices | No: the few prices it shows look like Japanese prices and aren't |
| **B. Its own prices; a finish with none falls back to the twin's, labelled** | The twin's prices, labelled, except the copied EUR, which shows unlabelled as its own | Its own prices | Mostly: the same numbers as C, but the copied EUR is labelled as the printing's own |
| **C. A printing with a twin shows the twin's prices, labelled as the English printing's; one with no twin shows its own** | The twin's prices, labelled "English printing" | Its own prices | Yes: every price says what it is |
| **D. No price for a non-English printing** | Nothing | Nothing | Drops real prices: the ★ planeswalkers, `sta`, `soa`, `4bb` and the others of §4b |

With the 2026-11-13 file, B and C show the same numbers on every printing but the 12 exceptions; they differ in the label. C is also what the design's display already says: "A collection row shows the price for its finish. Condition and language don't change it."

## Recommendation

**Option C.** A non-English printing that has an English twin shows the twin's price, named as the English printing's ("English printing · TCGplayer market price via Scryfall"); a printing with no twin shows its own. The file holds no price of a language for a printing that has a twin, so a blank (A) tells a collector of Japanese cards nothing and the copied EUR misleads, while C gives a reference price that says what it is. The language-only products, the ★ planeswalkers and the Japanese Mystical Archive among them, keep their real prices.

What follows for the issues after this one, for their specs to settle:

- **[#364](https://github.com/plainprogrammer/Collector/issues/364), the source contract:** Scryfall gives five series, not six (no etched EUR). The refresh stores what the file carries for every printing, the copied EUR included (7,667 quotes on 2026-11-13, §4): it is faithful to the source, and history already exists if Scryfall later prices a language. The choice of twin is a display rule, not stored.
- **[#365](https://github.com/plainprogrammer/Collector/issues/365), the daily refresh:** reading the catalog's file, as designed, is right for prices. For an instance with Japanese only, `default_cards` would give the same prices, at about a fifth of the download (81 MB against 408 MB); with German or Portuguese it would lose 338 language-only prices. Which file the price refresh reads stays the design's (the catalog's), unless #365 rules otherwise.
- **[#369](https://github.com/plainprogrammer/Collector/issues/369), the display:** the card page and a collection row of a non-English printing look up its twin by set code and number, and the label names the English printing. A lot's language doesn't change its price, as the design says; the label says why.

## The maintainer's ruling

Pending.
