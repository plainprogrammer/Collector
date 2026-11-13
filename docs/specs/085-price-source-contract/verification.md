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

Examples per file (counted with `bin/rspec --dry-run`): `prices_spec` 3, `prices/sources_spec` 14, `price_quotes_spec` 17 when the review ran and 18 now (the UTF-8 example below), the timing example excluded by default (`:timing`), `price_series_spec` 4, `price_source_spec` 6, `price_source_core_spec` 2. The full suite and the one full `bin/ci` run are the push's pre-push hook (the coordinator's ruling: one full CI run).

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

SPEC-ALIGNED: every AC, FR and decision of spec 085 v1.0.4 is built and proved by a test or by reading; nothing reaches into #365, #366 or #369.

Review (`sdd-review` Mode B, read-only, Opus 5.5, 2026-11-13) of commits `16c00d8e..b9f32016`: a coverage matrix of every AC (1.1 to 4.3), FR-1 to FR-3 and decisions 1 to 12 against the specs and the code, with every row OK. It checked the core files for collectible names (none), the one home of the hosted flag (`price_quotes.rb`, one example), the comments against the code, and the documents against the code. It did not run the suite.

Findings and what was done:

| # | Severity | Finding | Resolution |
|---|---|---|---|
| 1 | minor | A line with invalid UTF-8 makes `line.strip` raise and stops the whole read, against the reliability NFR and the Error Scenarios row "A line isn't JSON" | Fixed test-first in `38780d34`: an example writes a gzip with a `\xFF` byte and a good line after it (red: `Encoding::CompatibilityError` from `String#strip`), and `each_card_record` now yields a `Malformed` first (`valid_encoding?`). The catalog's `entry_or_malformed` (`app/models/mtg/scryfall/source.rb`) has the same gap; it is outside this spec, and is raised in the PR as a follow-up for the maintainer |
| 2 | nit | The contract header's member table lost its layout in the YARD site | Indented as a code block in `b80337dc` |
| 3 | nit | `verify_series!`, `https_or_nil?` and `refuse!` are public | Left as they are: they carry `@api private`, which the comment ratchet accepts; making them private class methods is a style choice with no behaviour |
| 4 | nit | `CLASS_MEMBERS` and `INSTANCE_MEMBERS` share one comment | Left: the comment covers both |
| 5 | nit | `prices.md` showed `(\.gz)?`, the code has `(?:\.gz)?` | Fixed in `5ca02247` |
| 6 | nit | The header didn't name `Malformed`'s `error` field | Added in `b80337dc` |

After the fixes: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb spec/price_source_core_spec.rb` gave `20 examples, 0 failures`; `bin/yard doc` gave 0 warnings.

## Distillation

`distill-feature`, 2026-11-13 (the feature is finished: SPEC-ALIGNED above), approved at the digest by the coordinator:

- **Area doc:** [`prices.md`](../../architecture/prices.md) carries the contract, the models, the sync, the constants, the decisions and the sources (T4.1), and a Distillation log row (the pull request reads "spec 085's pull request" until it has a number); the sentence on why an unreadable price is not an absence is in the contract's comment and in the doc (commit `8c4a58d0`). The Prices row of the [area map](../../architecture/README.md) lists 085.
- **Specs index:** row 085 is Frozen, by prices, with its plan owed a retirement after the merge; no supersession (spec 081 decision 5 stays true: the models for the three tables left are #365's and #366's). The 083 row says ruling 41 is distilled.
- **Spec:** the frozen line in its header (`e74c656b`, spec 027 D4). No ADR (Gate A).
- **CLAUDE.md:** its status paragraph points to the area doc (T4.2); nothing more restated.
- **Memory and lessons:** one memory (`mutation-proof-when-behaviour-already-built`) and three lessons in `docs/lessons/` (`2026-11-13-absent-is-not-unreadable`, `-never-name-a-contract-member-name`, `-the-polarity-of-a-flag-from-its-false`); the coordinator dropped a fourth (RuboCop-RSpec cops), which `.rubocop.yml` and the commit hook already tell an agent.
