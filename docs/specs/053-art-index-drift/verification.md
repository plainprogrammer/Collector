# Verification: Feature 053, An Art Index Built With Other Settings or For an Older Catalog Isn't Plain "Ready"

**Spec:** [spec.md](spec.md) v1.0.1 · **Plan:** plan (retired in `413bba67293c920ef392ff4ddb63ca16d383165f`; read it with `git show 413bba67293c920ef392ff4ddb63ca16d383165f^:docs/specs/053-art-index-drift/plan.md`) · **Issue:** [#176](https://github.com/plainprogrammer/Collector/issues/176)

## Red, then green, per phase

| Phase | Commit | Red (before the code change) | Green |
|---|---|---|---|
| 1. `MTG::ArtBuild#settings_drift?`, `#catalog_drift?`, `MTG::Art.latest_catalog_version` | `974e5989` | The three new examples failed, each `undefined method` for the reader (57 examples, 3 failures) | 57 examples, 0 failures |
| 2. The panel's `:out_of_date` state and the "Warning" fact | `71525399` | Five failed, reading `:ready` / "Ready." with no "Warning" fact: the AC-1.1–1.3 example, the AC-1.5 example, the AC-1.6 "out of date alone" example, and the two request examples of AC-1.10; the AC-1.4, AC-1.7, AC-1.8, AC-1.9 and AC-3.1 examples and "missing first" passed as guards (111 examples, 5 failures) | `operation_spec.rb`, `catalogs_spec.rb`, `admin_catalog_core_spec.rb`, `art_spec.rb`, `catalog_rake_spec.rb`: 151 examples, 0 failures |
| 3. The status line | `a82f4050` | AC-2.1 and AC-2.2 failed, the line reading "Art matching: ready; …"; AC-2.3 passed as a guard (28 examples, 2 failures) | `art_spec.rb`, `catalog_rake_spec.rb`, `scryfall/source_spec.rb`: 59 examples, 0 failures |
| 4. Building again, and the scanner pinned | `7b80f2f7` | Not observed: these are integration and characterization examples written after the code they exercise (Phase 4 adds no production code). AC-3.2 and AC-3.3 would fail without Phases 2 and 3 (their mid-example `:out_of_date` and "Warning" assertions are Phase 2's red examples at the integration level); AC-4.1 and AC-4.2 pin what the scanner already does | `build_spec.rb`, `art_indexes_spec.rb`: 36 examples, 0 failures |
| Review tightening | `8541838` | | `build_spec.rb`, `operation_spec.rb`: 94 examples, 0 failures |
| 5. Documents | `087fa10`, `9fbb0a7` | Reading-verified (the Distillation section) | |

Targeted run after Phase 4: `spec/models/mtg`, `spec/requests/admin`, `spec/requests/scanner`, `spec/tasks` and `spec/admin_catalog_core_spec.rb`: 583 examples, 0 failures; `spec/models/catalog/refresh_run_spec.rb` and `spec/backup_restored_art_spec.rb`: 29 examples, 0 failures; `bin/rubocop`: 649 files, no offenses.

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1–1.3 | `spec/models/mtg/art/operation_spec.rb` "says it is out of date when built with other settings, with its facts and a button": state, summary, `startable?`, no meter, `failed_job?` false, `record_running?` false, the seven labels in order and their values |
| AC-1.4 | `operation_spec.rb` "is plain ready at the current settings and the latest catalog" |
| AC-1.5 | `operation_spec.rb` "stays ready with a warning fact last when built for an older catalog" |
| AC-1.6 | `operation_spec.rb` "says out of date alone when both drifted" and "reads a missing file as missing, whatever the settings" |
| AC-1.7 | `operation_spec.rb` "judges no settings for a build with no digest", "judges no catalog for a build with no catalog version", "judges no catalog when the latest applied refresh has no version"; the truth tables in `spec/models/mtg/art_build_spec.rb` and `spec/models/mtg/art_spec.rb` (`.latest_catalog_version`) |
| AC-1.8 | `operation_spec.rb` "is queued while a build job waits", "is building while a later build runs", "is failed, worded as before, when the latest build failed" (each with a drifted older build) |
| AC-1.9 | `operation_spec.rb` "makes no drift comparison" (the index file test is stubbed true, so a build past `:off` would read `:out_of_date`) |
| AC-1.10 | `spec/requests/admin/catalogs_spec.rb` "says a finished build is out of date, with its facts and an enabled button, and doesn't poll" (no Failed-list link either) and "shows a warning under Ready. for a build made for an older catalog, with an enabled button, and doesn't poll"; a member's 404 is the existing "is invisible to a member: 404, and nothing is queued" (AC-7.1) |
| AC-2.1 | `spec/models/mtg/art_spec.rb` "says the index is out of date when built with other settings, and what to press" |
| AC-2.2 | `art_spec.rb` "adds a warning to the ready line when built for an older catalog" |
| AC-2.3 | `art_spec.rb` "judges nothing of a blank, and reads a missing file first", and the existing line examples (running, stalled, interrupted, failed, off, none, ready, missing), unchanged |
| AC-3.1 | `catalogs_spec.rb` "queues one build when Build art index is pressed with the index out of date" |
| AC-3.2 | `spec/models/mtg/art/build_spec.rb` "builds an out of date index again from the cached images without an image request, and reads ready again": first build under a stubbed digest, `:out_of_date` and the status line, then a build with no HTTP request, `fetched_count: 0`, a file named for the current digest, `:ready` |
| AC-3.3 | `build_spec.rb` "builds again for a newer catalog, and the warning goes" |
| AC-4.1 | `spec/requests/scanner/art_indexes_spec.rb` "is offered to the page and served although its header digest isn't the page's, which the browser refuses"; the browser's refusal is the existing `spec/system/scanner_art_spec.rb` "says art matching isn't available, and sends text only, when the index doesn't match the page" |
| AC-4.2 | `art_indexes_spec.rb` "is offered and served for an older catalog, its header digest the page's, which the browser uses" |
| AC-5.1 | `087fa10`: `docs/architecture/catalog-operations.md`, read after the edit: the Glossary's "Ready (art index)" entry says what ready is judged by now; the panel table has the "Out of date" row and the "Ready." row's Warning fact; the status-line paragraph words both lines and the three rebuild cases; the accepted limit is reworded to the damaged file and a new open point records that a release changing the settings queues no rebuild; Sources and the Distillation log carry spec 053 and #176 (the Neighbours block names no issue, so there was nothing to remove there) |
| AC-5.2 | `087fa10`: `docs/architecture/scanner.md`, read after the edit: the digest paragraph and the art-status table's mismatch row say what the browser refuses and what it keeps using and that the admin pages show them; the open-issues line for #176 is removed, #176 moves to the fixed issues in Sources, and spec 053 is in Sources and the Distillation log |
| AC-5.3 | `087fa10`: `docs/specs/README.md` has the 053 row (Frozen, by both area docs; Plan "retirement owed") and the Supersedes and Superseded-by entries on the 039, 015 and 011 rows, as the spec's Supersedes section says (written with the spec, unchanged); no shipped spec was edited; the spec's own frozen line is `9fbb0a7` (spec 027 D4) |

- NFR Cost holds by reading: `finished_facts` asks `latest_catalog_version` only after `state == :ready`, and `MTG::Art.status_line` only in `ready_line`; no query-count example (the one in `catalogs_spec.rb` runs with art matching off).
- The problem statement's answer to the maintainer's first question (what the scanner does with each kind of drift) was run as a throwaway request example before the spec was written, then pinned by AC-4.1 and AC-4.2.
- Not done, by decision: a build queued by a release that changes the settings (Non-Goal); the area docs record it as an open point.

## Implementation review

SPEC-ALIGNED WITH FOLLOW-UPS (Opus, read-only, 2026-11-09, over `974e5989..7b80f2f7`; nothing blocking, nothing major).

- Every AC of Stories 1–4 and every FR and NFR has code behind it and an example that fails without it; FR-4 holds (the diff touches three `app/models/mtg/` files and specs only); the Problem Statement's description of the scanner matches the code; the two new strings follow the design system's voice.
- Three minor findings. (1) The AC-1.9 example's file was never written, so the not-called assertion couldn't fail for the reason it names: fixed, the index file test is stubbed true so a build past `:off` would read `:out_of_date` (`8541838`). (2) AC-3.2 didn't check the new file is named for the current digest: fixed, the example asserts it. (3) The AC-4.1 fixture is a hybrid (name at the current digest, header and row at another): kept, since the browser's refusal reads only the header and AC-4.1 allows a patched header.
- Suggestions kept as they are: `MTG::Art.latest_catalog_version` repeats the one query `MTG::Art::Build#call` makes (FR-4 forbids touching the build here); a ready panel makes two `last_applied` queries (the NFR allows one more).
- The documents (AC-5.1–5.3) were pending at the review, written by distillation.

## Distillation

Spec 053 is distilled into [catalog operations](../../architecture/catalog-operations.md) (all of it) and [scanner](../../architecture/scanner.md) (the page's behaviour with a drifted index), in `087fa10`; no area without a doc is involved. CLAUDE.md restates no rule this feature changed, so it is untouched. No decision needed an ADR. Two lessons: `docs/lessons/2026-11-09-a-not-called-guard-needs-a-fixture-that-reaches-it.md` and `docs/lessons/2026-11-09-probe-the-ruled-first-question-before-the-spec.md`. The plan's retirement is owed after the pull request merges.
