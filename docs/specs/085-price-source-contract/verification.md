# Verification: spec 085, a price source contract and Scryfall's prices through it (#364)

**Spec:** [`spec.md`](spec.md) (Approved 1.0.4) · **Plan:** [`plan.md`](plan.md) · **Branch:** `085-price-source-contract` · **Date:** 2026-11-13

## Evidence

Commands run in the worktree after the last implementation commit (`b96c8c55`), on `db:prepare`d test databases:

| Command | Result |
|---|---|
| `bin/rails zeitwerk:check` | `All is good!` |
| `bin/rspec spec/models/prices_spec.rb spec/models/prices spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/price_series_spec.rb spec/models/price_source_spec.rb spec/price_source_core_spec.rb spec/prices_core_spec.rb spec/prices_schema_spec.rb spec/models/prices_record_spec.rb spec/models/mtg/scryfall` | `155 examples, 0 failures` (seed 17807) |
| `bin/ci checks` | `Continuous Integration passed in 39.53s`: RuboCop, YARD without warnings, the comment ratchet, Brakeman (0 warnings), bundler-audit, importmap audit |
| `git status --short db/` | empty: no schema or structure file changed, no migration |

Examples per file (counted with `bin/rspec --dry-run`): `prices_spec` 3, `prices/sources_spec` 14, `price_quotes_spec` 17 with the timing example excluded by default (`:timing`), `price_series_spec` 4, `price_source_spec` 6, `price_source_core_spec` 2. The full suite and the one full `bin/ci` run are the push's pre-push hook (the coordinator's ruling: one full CI run).

Timing, `SCANNER_TIMING=1 bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb -e "reads 50,000 cards"`: `price quotes: 300000 quotes from 50,000 cards in 1.2 s` (dev machine; no threshold).

**T2.3's mutation proof** (plan exception to failing-first, accepted at Gate B; the four mutations and their failures are in commit `14a321b9`'s body): (1) a fixed date instead of `reported_on(path)` fails the no-date and the all-cards-date examples; (2) `gzip.read.each_line` fails the stream example (`yielded` stays empty); (3) `id.upcase` fails the catalog-file example; (4) a language filter after the Hash guard fails the Japanese-twin example.

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 | `prices/sources_spec.rb` ".verify!" returns the fake; the contract's comment (`app/models/prices/sources.rb` header) names each member, what it returns and each error, with a fake collectible in its examples: **verified by reading** (below) |
| AC-1.2 | `prices/sources_spec.rb`: the member table, key cases, address, series and missing-member examples; `Series` refusals |
| AC-1.3 | `prices_spec.rb` "the registry" |
| AC-1.4 | `prices/sources_spec.rb` "the contract shown by a fake source" |
| AC-1.5 | `prices/sources_spec.rb` "::Quote" |
| AC-1.6 | `prices_spec.rb` "the registered sources" |
| AC-2.1 to AC-2.8 | `price_quotes_spec.rb` "#each_quote", "#reported_on" |
| AC-2.9 | `price_quotes_spec.rb` "reads the file the catalog reads, and calls no one" |
| AC-2.10 | `price_quotes_spec.rb` "reads the file as a stream" (mutation 2) |
| AC-2.11 | `price_quotes_spec.rb` "its declaration"; ".hosted_paid_allowed?" (decision 9) |
| AC-3.1 to AC-3.6 | `price_source_spec.rb` ".sync!"; `price_series_spec.rb` ".ensure!" |
| AC-3.7 | `price_source_spec.rb` and `price_series_spec.rb` "the table" |
| AC-4.1 | `price_source_core_spec.rb` (substrings, stricter than the criterion's "as a word": issue #209; a sample-string example shows the matcher flags a name) |
| AC-4.2 | `bin/ci checks`: comment ratchet, YARD, RuboCop, Brakeman |
| AC-4.3 | **verified by reading** (below) |

## Verified by reading

- **AC-1.1's comment:** `app/models/prices/sources.rb` opens with the contract: the member table (`.key`, `.collectible_type`, `.title`, `.attribution`, `.attribution_url`, `.hosted_paid_allowed?`, `.series`, `#reported_on`, `#each_quote`), what `#each_quote` must and must not do, what each kind of `Malformed` means for absence, and the errors. Its examples are neutral ("widget_prices").
- **AC-4.3:** `docs/architecture/prices.md` (Scope, Glossary, nine new invariants, five constants rows, Decisions not in an ADR, Sources, each statement with its source), `CLAUDE.md` (status paragraph), `docs/roadmap.md` (#364 "Done: spec 085"), `docs/specs/README.md` (the 085 row from the plan commit; the 083 row now says ruling 41 is distilled into prices.md).
- **Race in `sync!` and `ensure!` (spec NFR):** read, not tested (a race can't be forced without stubbing the code under test): `PriceSeries.ensure!` is `find_by || create_or_find_by!` against the unique index; `PriceSource.sync!` retries a `RecordNotUnique` once.

## Deviations from the spec and plan

None in behaviour. The plan's one stated exception: T2.3's examples were written after the behaviour (mutation proof instead of failing-first, ruled by the coordinator at Gate B).

## Implementation review
