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

| File | `updated_at` | Compressed bytes | SHA-256 |
|---|---|---|---|
| `all-cards-20261113102214.jsonl.gz` | 2026-11-13T10:22:14.677+00:00 | 407,728,287 | `9fbca73ad5f680605487c576e639008d1075458592ccdbe44ec4d0c658a3e877` |
| `default-cards-20261113100623.jsonl.gz` | 2026-11-13T10:06:23.955+00:00 | 81,144,238 | `2d0d1bcd8f289ec31a342b6662554b4df2d8aed305ca5577c1e74b0030bedb5c` |

Scryfall doesn't keep old bulk files, so the checksum is how a rerun confirms it read the same input.

**Population.** The printings the catalog would hold and the price refresh would match: paper printings only, the test `MTG::Scryfall::Mapper.paper?` applies (`digital` false and `games` includes `paper`). Counts over every object, digital included, are given beside them for reference.

**Counts, by the script [`count_prices.rb`](count_prices.rb)** (Ruby standard library only; it streams the gzip file line by line, as `MTG::Scryfall::Source#each_entry` does, and prints Markdown tables):

1. Per language: card objects; objects with a `prices` key; objects whose prices are all empty.
2. Per language, finish and currency: of the printings whose `finishes` list that finish, how many carry a price in that currency (`usd`/`eur` for nonfoil, `usd_foil`/`eur_foil` for foil, `usd_etched`/`eur_etched` for etched). A finish the printing doesn't have isn't counted as empty.
3. Per language, non-English only: printings paired with the English printing of the same set code and collector number (its **English twin**), and printings with no twin. For each pair and each price: both empty, equal, different, priced only in English, priced only in the other language. For each pair and each finish the non-English printing has: the USD outcome and the EUR outcome together, so an equal pair shows whether it is equal in both currencies or in one (counts section 4a). For each pair: whether `tcgplayer_id` and `cardmarket_id` are present and equal to the twin's.
4. Whether the pairing holds (counts section 0): English paper printings that share a set code and number (a twin must be unique), and pairs whose two printings have different `oracle_id`s (a twin must be the same card). For each pair, the finishes the non-English printing has and its twin hasn't (section 4c), and the twin's `cardmarket_id` against the non-English printing's EUR price (section 5a).
5. Per language, the printings with no twin, by the reason the file shows (counts section 4b): the set has no English paper printing at all; the English printing of that number isn't paper; the number carries a ★ (and whether the number without it is in English); a plain number the set has no English printing of; a number with another mark. For each reason, how many carry any USD or EUR price, the five most common sets, and whether `default_cards` carries the printing too.
6. Every pair whose prices differ or whose non-English printing alone is priced, and up to ten example pairs of each other outcome for Japanese and three for another language, with set, number, both prices and the `cardmarket_id` relation, so a reader can check them on scryfall.com.
7. For card ids in both files: whether the `prices` objects are identical. And the non-English printings in `default_cards` (a card printed only in another language), which an English-only catalog leaves out.

The counts section numbers below (§0 to §8) are those of [`counts.md`](counts.md).

**Reproduce:** `ruby docs/specs/083-non-english-printing-prices/count_prices.rb ALL_CARDS.jsonl.gz DEFAULT_CARDS.jsonl.gz > counts.md`, with the two files of the table above; it took about two minutes on the dev machine. The output of the run reported here is [`counts.md`](counts.md). Prices change daily, so a later file gives other numbers; the shape of the findings is what this note relies on.

**Limits.** One day's file: what it lacks (an `eur_etched` key, a USD price on a non-English printing with an English twin) may appear in a later one. The note reads what Scryfall publishes, not what TCGplayer or Cardmarket list for a language: a price Scryfall leaves empty may exist on the marketplace. It doesn't ask Scryfall how it fills `prices` for a non-English printing; where the counts suggest a rule, the note says it is inferred.

## Findings

### Answer

- **Every card object has a `prices` object of its own,** in every language (§1). For a non-English printing it is almost always empty: 97.5% of Japanese paper printings (62,440 of 64,033) have no price at all, and 96.6% to 99.8% of every other major language. English: 5.4%.
- **A non-English printing with an English twin carries no price of its language.** Of 428,442 such printings in ten languages, none has a USD price, none has a `tcgplayer_id`, and where one has a EUR price (5,256 nonfoil, 2,411 foil) it is the twin's price, to the cent: 5,282 of the 5,293 printings with a EUR price carry the twin's `cardmarket_id` (§3, §4, §5a). The file holds 12 exceptions, and only 11 of them are a price of the language (§4, §5a, §7).
- **The pairing holds.** No two English paper printings share a set code and number, and every pair is the same card (`oracle_id`, §0). But 1,697 Japanese pairs (1,654 foil, 43 nonfoil) are for a finish the twin hasn't, so the twin has no price to lend for it (§4c).
- **A printing with no English twin has prices of its own,** often for Japanese (90.1% of foil, 30.9% of nonfoil) and less often elsewhere (none of the 370 Korean `4bb` printings, nor of the 370 Traditional Chinese): those are separate products, such as the Japanese War of the Spark planeswalkers numbered with a ★ (`war`, `pwar`) and the Japanese printings of `sta` and `soa` with numbers of their own (§3, §4b).
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

- **With an English twin (63,003).** USD: none. EUR: 947 nonfoil and 344 foil prices, every one equal to the twin's (§4); 962 Japanese printings with a twin carry the twin's `cardmarket_id`, 961 of them with a EUR price, and none an id of its own (§5, §5a). No pair has a USD price on both sides, so no pair is equal in both currencies (§4a: 944 nonfoil pairs are "USD English only, EUR equal", 3 are "USD both empty, EUR equal"; foil 340 and 4). Their English twins are priced as English printings are: `usd` on 61,480 of the 63,003 (§4). The examples with a copied EUR price come from sets such as `ltr`, `ltc`, `40k`, `vow`, `ncc` and `ddk` (§7). For 1,654 foil and 43 nonfoil pairs the Japanese printing lists a finish its twin doesn't; none of these is priced on the Japanese side, and in all but 3 the twin is priced for its own finishes (§4c).
- **No English twin (1,030), by reason (§4b):**

| Reason | Printings | Any USD | Any EUR | Most common sets |
|---|---|---|---|---|
| The set has no English paper printing | 662 | 143 | 263 | `4bb` 378, `bchr` 125, `pwcs` 46, `pmps` 20, `pjjt` 12 |
| A plain number the set has no English printing of | 228 | 225 | 226 | `soa` 130, `sta` 63, `sld` 16, `neo` 10, `iko` 3 |
| A ★ number whose plain number is in English | 74 | 60 | 74 | `pwar` 36, `war` 36, `dd2` 2 |
| A number with another mark | 60 | 43 | 54 | `pmei` 47, `plg24` 6, `plg21` 3 |
| A ★ number whose plain number isn't in English | 6 | 2 | 6 | `pwwk` 2, `pm11`, `proe`, `purl`, `pzen` |

Every Japanese `tcgplayer_id` in the file (512, §1) is on a printing with no English twin. Of the 1,030, `default_cards` carries 652 and lacks 378, all Japanese Foreign Black Border (`4bb`), and none of the 378 is priced (§4b, second table).

### The other languages

The same pattern holds for French, German, Spanish, Italian, Simplified and Traditional Chinese, Portuguese, Russian and Korean (§3 to §5): no USD price on any printing with an English twin; a EUR price on 0.2% to 1.7% of them, equal to the twin's (but for the 12 exceptions below) and under its `cardmarket_id`; a finish the twin hasn't on 10,962 foil and 329 nonfoil pairs (§4c). The exceptions, 12 prices of 428,442 pairs (§7 lists them all):

- 11 Spanish printings, 7 Portal (`por`) and 4 Introductory Two-Player Set (`itp`), with a `cardmarket_id` of their own and a EUR price that differs from the English one (median ratio 0.83, §6). By their own `cardmarket_id`, these are the only prices of a language on a printing with a twin (inferred, see below).
- 1 French printing (`bro` 379) with a nonfoil EUR price. Its English twin is foil only, so it has no `eur` (its `eur_foil` is 0.25); the French object lists nonfoil and carries 0.16 under the twin's `cardmarket_id`. It is the one priced row of §4c, a finish the twin hasn't, and not equal to any price of the twin.

The printings with no twin are mostly language-only sets (§4b): Foreign Black Border (`4bb`, `fbb`), the Renaissance sets (`ren`, `rin`), Salvat (`psal`, `ps11`), the Japanese `bchr`; and the languages of a few cards (`ph`, `tlh`, `qya`, `dw`, `grc`, `ar`, `he`, `la`, `sa`), every one with no twin.

### The two files

- All 120,063 card ids of `default_cards` are in `all_cards`, with identical `prices` (§8). `default_cards` also carries 2,660 non-English objects, a card's only language (§8), which an English-only catalog leaves out today (spec 002 FR-3): the source keeps only the configured languages.
- The printings with no twin that `all_cards` alone carries are priced only for German (119 of 428, `fbb` and `ren`) and Portuguese (219 of 375, `4bb`); none for Japanese, whose 378 are all `4bb` (§4b, second table).
- `default_cards` carries no non-English printing that has a twin: its paper count per language equals the printings with no twin it carries (§4b, §8). So it lacks the copied EUR prices (7,667 quotes) and the 12 exceptions; under option C below none of them is shown, so it would show the same prices for every printing a catalog with Japanese holds.

### Inferred, not confirmed

- Scryfall fills a printing's prices from the marketplace ids on that card object. TCGplayer ids are on English printings and on language-only printings; a non-English printing of an English card has none, so it has no USD. Some non-English printings carry the English printing's `cardmarket_id`, so they show the English printing's EUR (§5a: every paired printing with a EUR price has a `cardmarket_id`, and every one but the 11 Spanish has the twin's). The note didn't ask Scryfall.
- So a non-English printing's EUR, where present, is not a price for that language: it is the same number as the English printing's and can't be told apart from it.
- Cardmarket may list one product for every language of a printing, with the language a property of each offer; the shared `cardmarket_id` fits that. If so, the EUR price of an English printing is already a price across languages, and "English printing" is exact only for USD (TCGplayer's market price of the English printing). Not checked here; it bears on the label (#369).

## Options for what a non-English printing shows

A **twin** is the English printing of the same set code and collector number. The catalog always holds English (`MTG::Scryfall::Source#languages` adds `en`), so a twin in the file is a twin in the catalog. A printing with no twin is a product of its own.

| Option | A Japanese printing with a twin shows | A printing with no twin shows | Fair to the data? |
|---|---|---|---|
| **A. Its own prices only** | Nothing on 98.5% of nonfoil and 99.2% of foil; a EUR price on the rest, presented as its own though it is the English one | Its own prices | No: the few prices it shows look like Japanese prices and aren't |
| **B. Its own prices; a finish with none falls back to the twin's, labelled** | The twin's prices, labelled, except the copied EUR, which shows unlabelled as its own | Its own prices | Mostly: the same numbers as C, but the copied EUR is labelled as the printing's own |
| **C. A printing with a twin shows the twin's prices for the same finish, labelled as the English printing's; one with no twin shows its own** | The twin's prices, labelled "English printing"; nothing for a finish the twin hasn't | Its own prices | Yes: every price says what it is |
| **D. No price for a non-English printing** | Nothing | Nothing | Drops real prices: the ★ planeswalkers, `sta`, `soa`, `4bb` and the others of §4b |

With the 2026-11-13 file, B and C show the same numbers on every printing but the 12 exceptions, of which only the 11 Spanish are a price of the language; they differ in the label.

Under C, a finish the twin hasn't (§4c: 1,654 Japanese foil and 43 nonfoil pairs) has no price to show. The twin's other finish is a different product at a different price, so it isn't lent. Such a finish shows no price, like any unpriced printing. Of all these pairs in every language, one has a price of its own for that finish (French `bro` 379, above): B would show it, C doesn't.

C is consistent with the design's display: "A collection row shows the price for its finish. Condition and language don't change it." The design names no twin and no label; it predates this finding.

## Recommendation

**Option C.** A non-English printing that has an English twin shows the twin's price for the same finish, named as the English printing's (for example "English printing · TCGplayer market price via Scryfall"); a finish the twin hasn't shows no price; a printing with no twin shows its own. The file holds no price of a language for a printing that has a twin, so a blank (A) tells a collector of Japanese cards nothing and the copied EUR misleads, while C gives a reference price that says what it is. The language-only products, such as the ★ planeswalkers and the Japanese `sta` and `soa` printings, keep their real prices. C gives up the 11 Spanish prices of a language, which B would show.

What follows for the issues after this one, for their specs to settle:

- **[#364](https://github.com/plainprogrammer/Collector/issues/364), the source contract:** the 2026-11-13 file has five series, not six (no etched EUR); the contract should take an etched EUR if one appears rather than rule it out. The refresh stores what the file carries for every printing, the copied EUR included (7,667 quotes on 2026-11-13, §4): it is faithful to the source, and history already exists if Scryfall later prices a language. The choice of twin is a display rule, not stored.
- **[#365](https://github.com/plainprogrammer/Collector/issues/365), the daily refresh:** reading the catalog's file, as designed, keeps the point above: every printing's quotes are stored. Under C, an instance with Japanese only would show the same prices from `default_cards`, at about a fifth of the download (81 MB against 408 MB), but would store none of the copied EUR or the 12 exceptions; with German or Portuguese it would lose the prices of 338 language-only printings. Which file the price refresh reads stays the design's (the catalog's), unless #365 rules otherwise.
- **[#368](https://github.com/plainprogrammer/Collector/issues/368), the history levels:** under C an owned Japanese printing displays its twin's price, and the twin isn't owned. The tracked level should count the twin of an owned non-English printing as tracked, or the price a collector sees has no history at that level.
- **[#369](https://github.com/plainprogrammer/Collector/issues/369), the display:** the card page and a collection row of a non-English printing look up its twin by set code and number (unique, §0), for the lot's finish, and the label names the English printing. The label's wording for EUR depends on whether Cardmarket's price is per language (see "Inferred, not confirmed"). A lot's language doesn't change its price, as the design says; the label says why.

## Reviews

Read-only reviews of the method and the findings, on Fable 5.2, 2026-11-13:

- **Round 1: APPROVE WITH CHANGES.** 3 major (the Spanish exceptions are `por` and `itp`, not all `por`; a finish the twin hasn't; option C and the tracked history level), 9 minor and 6 nits. The reviewer streamed `all_cards` to check the pairing. All resolved: the script gained §0, §4c and §5a, and the note was corrected.
- **Round 2: APPROVE WITH CHANGES.** All round 1 findings resolved and the new numbers checked against `counts.md`. 1 minor (the French `bro` 379 is a finish the twin hasn't, not a day's gap) and 3 nits, all resolved.

## The maintainer's ruling

Pending.
