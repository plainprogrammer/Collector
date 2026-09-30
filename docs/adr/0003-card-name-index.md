# 0003: Index card names with an FTS5 trigram table

## Status

Proposed

## Context

The scanner turns misread name-bar text into card candidates from the local catalog, quickly and within the app's schema conventions (spec 005, Story 3). The catalog has no name index for fuzzy matching.

Phase 0 built a trigram index over the full English catalog in a separate SQLite file ([research.md](../specs/005-card-scanner-phase-0/research.md), Section 5):

- An external-content FTS5 table (`content='names'`, `content_rowid='id'`, `tokenize='trigram remove_diacritics 1'`) survives Rails 8.1.4's `schema.rb` dump and load: the SQL is identical and a trigram query finds rows afterwards. The dump line is `create_virtual_table "names_fts", "fts5", ["norm", "content='names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'"]`.
- 35,986 names (each distinct full name, plus each face of a multi-face card, de-duplicated) build in a median 3.04 s including the catalog read (n=3), in a 7,086,080-byte file of which the FTS5 tables are 2,416,640 bytes.
- Querying the OR of the query's trigrams, taking the best 50 by `bm25` and re-ranking by Jaro-Winkler (stdlib `DidYouMean::JaroWinkler`) took a median 10.14 ms and a 95th percentile of 114.46 ms (n=50). The correct card was top on 20 of 50 photos and in the top 3 on 26 of 50, limited mostly by noisy OCR input.
- Diacritics, ligatures and long multi-face names are found exactly and with one misread character. Failures: names that normalise to nothing (`_____`), short names and faces with one misread (`Ox`, `Fixe`, `Ixe`, `St0mp`), and long noisy queries that dilute the ranking.

## Decision

- Add a `names` table (card name, indexed name, normalised name) and an external-content FTS5 `names_fts` table with `tokenize='trigram remove_diacritics 1'`, created by a migration with `create_virtual_table` and kept in `schema.rb`.
- Index each distinct full name and each face name of multi-face cards, normalised identically to queries (NFKC, ligatures such as "Æ" to "ae", diacritics, case, apostrophes, punctuation).
- Rebuild the index in full after each catalog refresh that applies a new source version (about 3 s against a 61 s refresh), as part of the refresh's background work.
- Rank by OR-ing the query's trigrams, shortlisting 50 by `bm25`, re-ranking by Jaro-Winkler and keeping each card's best row.
- Add three fallbacks: clean the query first (take the longest mostly-alphabetic line, drop tokens under 3 characters); when the normalised query is empty, match the raw text exactly; for short queries, accept an edit distance of at most 1 over names of similar length.

## Consequences

- Name matching stays in SQLite with no extra gem or extension, and the schema remains `schema.rb`.
- The index is global catalog data (no `account_id`), derived and rebuildable at any time.
- Each refresh takes about 3 s longer (median, n=3, measured on the development machine; self-hosters' hardware will differ).
- The index lives in the primary database, so it adds about 7 MB to it and to its backups (estimate from the spike's separate file).
- The fallbacks are proposed, not measured; Phase 1 should measure them against the committed fixtures.
- Flavour names (for example Secret Lair cards) can't be matched until the catalog stores them.
