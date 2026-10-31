# Spike #145: Where CI's Time Goes, and Whether to Split It

**Issue:** [#145](https://github.com/plainprogrammer/Collector/issues/145)
**Measured:** 2026-10-31, in a cloud session on branch `035-ci-shards` at `129294d` (`main`)
**Ruled:** 2026-10-31 by the maintainer, in the session: see [Recommendation and rulings](#recommendation-and-rulings)

This note answers the issue's four questions with measurements. The build that follows the rulings is [spec 035](spec.md).

## Where measured

- **Cloud session:** Ubuntu 24.04, 4 cores, 15 GB, Ruby 4.0.7. Firefox ESR 153.6.0 and geckodriver 0.36.0 were installed by hand (Mozilla's tarballs), because the image has no Firefox; libvips 42 and ImageMagick (`convert`) were present; the OCR engine was fetched by `bin/setup`. Nothing else was running.
- **GitHub:** the `ci` job's logs and step timings of runs `40566002131`, `40560117232`, `40534039300` and `40527511006` (2026-10-27), through the REST API.

## 1. Where the time goes

### One example is 82% of the suite

A full `bin/rspec --profile 60 --format json` (seed 329): **2,357 examples, 0 failures, 3 pending, 30 min 12 s** (1,811.8 s). Per-file sums from the JSON:

| Part | Seconds | Share |
|---|---:|---:|
| `spec/models/location/name_parity_spec.rb` (5 examples) | 1,518.3 | 83.8% |
| of which line 69 (one example) | 1,486.5 | 82.0% |
| of which line 21 (one example) | 31.3 | 1.7% |
| System specs (36 files, 144 examples) | 150.2 | 8.3% |
| Everything else (182 files, 2,208 examples) | 142.7 | 7.9% |

No other file takes more than 14.1 s (`spec/script/upgrade/harness_spec.rb`); the slowest example outside the parity file is 6.5 s (`spec/system/admin_catalog_spec.rb:42`).

**The cause.** Both examples sweep every Unicode scalar value (1,112,064) in four forms. Line 21 judges each string with `let(:pattern)`, a regular expression built once. Line 69 uses `def lot_pattern = Regexp.new(JSONSchemer::EcmaRegexp.ruby_equivalent(lot_location["pattern"]))`, a method, so it translates and compiles the schema's pattern again for every string it judges. That example came with export format version 3 (`5ed5218`, 2026-10-24, spec 032 AC-9.7), which is when `bin/ci` went from minutes to about 20 minutes (spec 032's `verification.md`: RSpec 21 min 31 s).

**The fix, measured.** A copy of the file with `def lot_pattern` turned into `let(:lot_pattern)` (the same expression, built once per example; nothing else changed): the file passes, line 69 takes **20.7 s** (from 1,486.5 s), the file 53.8 s. The whole suite with that copy in place of the file (seed 36498): **2,357 examples, 0 failures, 5 min 54 s** (353.6 s).

### The other steps are cheap

Each `bin/ci` step on its own, in the cloud session:

| Step | Seconds |
|---|---:|
| `bin/setup --skip-server` (bundle and OCR engine already present) | 5.1 |
| `ruby script/upgrade/guard.rb` | 0.1 |
| `bin/rubocop` | 5.7 |
| `bin/brakeman …` | 7.1 |
| `bin/bundler-audit` | 1.8 |
| `bin/importmap audit` | 1.5 |

GitHub's logs agree: the six steps before RSpec take 18–25 s, and RSpec took 19 min 57 s (run `40566002131`) and 29 min 17 s (run `40534039300`). The guard fails in a checkout without tags ("this checkout has a remote but no tags"), so any job that runs it needs `fetch-depth: 0`, as the `ci` job has today.

### After the fix

From the second run's JSON (the fixed copy counted as one file):

| Part | Seconds | Share |
|---|---:|---:|
| System specs | 153.3 | 43.4% |
| The parity file | 56.2 | 15.9% |
| Request specs | 52.3 | 14.8% |
| Everything else | 191.1 | 25.9% |

A greedy split of the 219 files by these timings gives shards of 176 s (2), 118 s (3), 88 s (4) and 59 s (6), each before its job's setup. The parity file (56 s) is the floor for any number of shards, unless it is split.

## 2. GitHub Actions

- **Cost of a job:** in run `40566002131` the `ci` job's setup took 19 s before `bin/ci` (checkout 2 s, Ruby with the bundle cache 4 s, apt for libvips and ImageMagick 12 s), then `bin/setup` 6–9 s and the six cheap steps. Firefox and geckodriver come with GitHub's Ubuntu runner image; the session had to install them by hand.
- **Runners:** the repository is public, so standard runners have 4 vCPUs and minutes are not billed.
- **Branch protection:** `main` has none and no rulesets (`protected: false`), so no check is required by name today.
- **The image jobs** take 2–4 min after `ci` (build 88–122 s when not cached, backup smoke 23–26 s, upgrade smoke 44–48 s). They wait for `ci` (`needs: ci`); a matrix job named in `needs` waits for every leg.
- **Options:** (a) one `ci` job as today; (b) lint and security in their own job beside RSpec: saves about 20 s, adds a job; (c) RSpec sharded across a matrix by recorded timings, with a job that gathers the verdict; (d) system specs in one job and the rest in another: 153 s against 200 s, a fixed split that drifts as specs are added.
- **One CI definition:** `config/ci.rb` is plain Ruby run by `ActiveSupport::ContinuousIntegration` (Rails 8.1.4), which has no groups of its own; the file can choose its steps from an argument, so the workflow can keep calling `bin/ci` and list no check (spec 001 AC-2.5).
- **A prior design:** plainprogrammer/ClientKennel (its spec 016) splits its system specs into four CI slices and local workers with `parallel_tests` 5.8: `--group-by runtime` from a committed run-time log (`--allowed-missing 100`, file size when there is no log), `--only-group N` so every machine forms the same slices, the replay command and seed printed per slice, and an aggregate `system-test-complete` job. It measured that a fifth slice added minutes without making the wall time more reliable (GitHub's job completion varied by tens of seconds). Its workflow lists each check per job and does not call `bin/ci`, which Collector's rule forbids.

## 3. Locally (`bin/ci` and the pre-push hook)

- **The pre-push hook does not gate today.** Its `timeout` is 900 s; `bin/ci` takes 20–30 min. The Claude Code hooks documentation (code.claude.com/docs/en/hooks, "Timeouts"): a timed-out `PreToolUse` command hook is cancelled and "doesn't block the tool call … To block the call when a `command` or `http` hook times out, set `onFailure: "block"`" (Claude Code 2.1.295 or later; this session runs 2.1.316). So since spec 032 a push has gone ahead without `bin/ci` finishing, which is what the memory "push in background" saw ("the hook may print nothing about `bin/ci`").
- **Parallel RSpec locally** (`parallel_tests`, one database per process through `TEST_ENV_NUMBER`) solves the database; the suite also shares files that would need a path per process: the art cache `tmp/catalog/mtg/art` (every `:art_matching` example deletes it before and after), Active Storage's test root `tmp/storage` (emptied by an `after(:suite)` hook), and the system specs' `tmp/downloads`. The `:committed` backup examples empty only their own process's database, so they would be safe. Not needed now: ruled out (see Recommendation and rulings).
- **A documentation-only fast path:** the suite reads documentation in one place, `docs/export-format/` (the schemas, the examples and the README, spec 020 decision 7). A search of `spec/`, `lib/`, `app/`, `config/` and `script/` finds no other code that reads a file under `docs/`, `.claude/` or a Markdown file (`spec/image_publishing_spec.rb` names such paths as `.dockerignore` entries; `spec/script/upgrade/harness_spec.rb` names `docs/releasing.md` in a message). Files under `docs/` that aren't Markdown are screenshots, design-system previews, `tokens.json` and the export format's files.

## 4. Determinism

- **Shards keep a seed each.** RSpec randomises within each process; a shard's order is reproducible from its files and its seed, so a shard must print both, and the replay command must run the same files with the same seed. `rspec --bisect` works within one shard's files.
- **Cross-file leaks can hide or appear.** A test that passes only after another file ran (or fails only after it) behaves differently once the two files are in different shards. Running the whole suite in one process stays possible (`bin/rspec`), and local `bin/ci` stays serial (ruled), so the serial order is still exercised before every push.
- **Shared state on GitHub:** each job has its own runner and checkout, so `storage/test.sqlite3` and `tmp/` are never shared between shards.

## Recommendation and rulings

| Question | Recommended | Ruled (2026-10-31) |
|---|---|---|
| The parity example | Fix it first, on its own | **Its own small fix PR**, ahead of the rest |
| The hook's timeout | Block on timeout, timeout with headroom | **Block on timeout** (`onFailure: "block"`), on both git hooks; after the spec review, **shipped as an issue fix** beside the parity fix, not in spec 035 |
| Splitting and parallelising | Not now: about 6 min after the fix; print the slowest examples; revisit past a budget | **GitHub shards now**; `bin/ci` learns step groups; local `bin/ci` stays serial (spec 035) |
| A documentation-only fast path | Not now: GitHub stays the gate, and 6 min is short | **Yes, with exclusions:** `docs/export-format/**`, `.claude/settings.json` and `.claude/hooks/` are code (spec 035) |

The rulings are the inputs of [spec 035](spec.md). After the maintainer rules on this note, `docs/roadmap.md` gets a housekeeping line for #145 and a line for spec 035 (issue #145's comment).
