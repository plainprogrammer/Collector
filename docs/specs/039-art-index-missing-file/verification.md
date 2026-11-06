# Verification: Feature 039, A Finished Art Build Whose Index File Is Missing Isn't "Ready"

**Spec:** [spec.md](spec.md) v1.0.1 · **Plan:** [plan.md](plan.md) · **Issue:** [#122](https://github.com/plainprogrammer/Collector/issues/122) · **Pull request:** [#175](https://github.com/plainprogrammer/Collector/pull/175)

## Red, then green, per phase

| Phase | Commit | Red (before the code change) | Green |
|---|---|---|---|
| 1. `MTG::Art::Index.file?`, `MTG::ArtBuild#index_file_present?` | `446b507` | `index_spec.rb` "knows whether a file of its name is there" and `art_build_spec.rb` "#index_file_present?" failed, neither method existing yet (the latter: "expected … to respond to `index_file_present?`") (35 examples, 2 failures) | 35 examples, 0 failures |
| 2. The panel's `:index_missing` state | `f73f537` | The four new missing-state examples (AC-1.1–1.3, both AC-1.5, AC-1.8) failed, reading `:ready` / "Ready."; the AC-1.4, AC-1.6 and AC-1.7 guards passed (94 examples, 4 failures) | 94 examples, 0 failures; with the other readers of the art line and panel (`art_spec.rb`, `catalog_rake_spec.rb`, `scryfall/source_spec.rb`, `backup_restored_art_spec.rb`, `admin_catalog_core_spec.rb`): 150 examples, 0 failures |
| 3. The status line | `5712f67` | AC-2.1's two examples failed, the line reading "Art matching: ready; …" (24 examples, 2 failures) | 55 examples, 0 failures (`art_spec.rb`, `catalog_rake_spec.rb`, `scryfall/source_spec.rb`) |
| 4. Building again restores "Ready." | `474ee49` | With Phase 1's `operation.rb` and `art.rb` put back: AC-3.2 failed (`expected: :index_missing`) and AC-1.8 likewise; AC-3.1 passed, a guard (the controller is unchanged, as the spec says) | 3 examples, 0 failures; `build_spec.rb`, `catalogs_spec.rb`, `backup_restored_art_spec.rb`: 66 examples, 0 failures |
| 5. Documents | `fa3a0f4` | Reading-verified (below) | |

Full local `bin/ci` at `474ee49` (the last code commit; later commits are documents and images): every step passed, RSpec 2435 examples, 0 failures, 1 pending, in 5m59s. The pre-push hook's full `bin/ci` (it blocks on failure) let the push of `80aad73` through.

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 | `spec/models/mtg/art/operation_spec.rb` "says the index file is missing, shows the build's facts and can be built again" |
| AC-1.2 | Same example: labels in order `Finished, Index file, Artworks indexed, Without an image, Failed images` and their values |
| AC-1.3 | Same example: `startable?` true, `meter` nil, `failed_job?` false, `record_running?` false; the request example of AC-1.8 finds no `poll` controller |
| AC-1.4 | `operation_spec.rb` "is ready while the named file is there"; the updated AC-4.7 example also checks no "Index file" fact |
| AC-1.5 | `operation_spec.rb` "reads a row with no file name as missing, with none recorded" and "reads a name of another shape as missing and shows it as stored"; that nothing outside `index/` is examined is `MTG::Art::Index.file?`'s `NAME` check, proven in `index_spec.rb` with `../../config/master.key` |
| AC-1.6 | `operation_spec.rb` "is queued while a build job waits", "is building while a later build runs", "is failed, worded as before, when the latest build failed" |
| AC-1.7 | `operation_spec.rb` "looks at no file, whatever the latest build names" (art matching off; `MTG::Art::Index.file?` spied, never called) |
| AC-1.8 | `spec/requests/admin/catalogs_spec.rb` "says a finished build's index file is missing, with its facts and an enabled button, and doesn't poll"; a member's 404 is the file's existing generic example |
| AC-2.1 | `spec/models/mtg/art_spec.rb` "says the index file is missing, and what to press" and "says no file name was recorded for a finished build without one" |
| AC-2.2 | `art_spec.rb` "reports a finished build's counts and index" (now with a real file) |
| AC-2.3 | `art_spec.rb`'s existing running, stalled, interrupted, failed, off and no-build examples, unchanged and green |
| AC-3.1 | `catalogs_spec.rb` "queues one build when Build art index is pressed with the index file missing" |
| AC-3.2 | `spec/models/mtg/art/build_spec.rb` "writes a missing index file again without an image request, and reads ready again" (ImageMagick present; every request blocked after `WebMock.reset!`) |
| AC-4.1 | `docs/architecture/catalog-operations.md`: Glossary "Ready (art index)"; the art index table's two Finished rows; the status-line paragraph; Accepted limits (judged by name only); Sources (spec 039, #122). Read on 2026-11-05 |
| AC-4.1a | `docs/architecture/release-and-deploy.md`: Neighbours line, the #122 limit reworded as fixed, Sources (spec 039; #122 moved from open to fixed). Read on 2026-11-05 |
| AC-4.2 | `docs/specs/README.md`: the 039 row's Supersedes names 015 AC-4.1, 011 AC-3.11 and 030 decision 12, each in part; the 015, 011 and 030 rows' Superseded-by cells name 039 (the 030 row's text moved from a stray seventh cell into Superseded by). No shipped spec edited (`git diff origin/main -- 'docs/specs/0[0-2]*' 'docs/specs/03[0-8]*'` is empty). Read on 2026-11-05 |
| AC-4.3 | `README.md`'s Restore paragraph and "After a restore" checklist say the page and `catalog:status` read "Index file missing" until **Build art index** is pressed; `docs/backup-restore.md` and `lib/collector/backup/restore.rb` unchanged. Read on 2026-11-05 |

## Demonstration

`/admin/catalog` with art matching on, the art build row seeded by a scratch script into the worktree's dev database (an empty index written through `MTG::Art::Index.write!` for "ready", deleted for "missing"): [screenshots/](screenshots/) 01–04, light and dark. `catalog:status[mtg]` output for both states is in the pull request body.

## Implementation review

SPEC-ALIGNED WITH MINOR GAPS (sdd-review Mode B, Opus, read-only, 2026-11-06, on `80aad73`); the minor gaps it named are closed or ruled below, so the feature stands spec-aligned.

Every AC was covered by a test or a reading (the table above matches the reviewer's). FR-1 to FR-4, the NFRs, decisions 1 to 6, the error-scenario table and the Supersedes section match the code; FR-4 held (nothing under `app/controllers`, `app/views`, `app/helpers` or `app/models/catalog` changed). No blocking or major findings. The minor ones:

| # | Finding | Handling |
|---|---|---|
| 1 | README quoted the panel's words for `catalog:status` | Fixed in `7633920`: it quotes "Art matching: index file missing" |
| 2 | AC-2.2's guard matched substrings only | Fixed in `7633920`: the whole ready line is compared |
| 3 | AC-1.6 had no interrupted example behind a missing-file build | Fixed in `7633920`: one example (stalled takes the same `running?` branch) |
| 4 | `verification.md` uncommitted; `Gemfile.lock` noise | This commit; the local arm64-darwin `Gemfile.lock` change stays uncommitted |
| 5 | The settings-drift follow-up issue is unfiled | Filed by the coordinator as [#176](https://github.com/plainprogrammer/Collector/issues/176) |
| 6 | The upgrade seeds' `art-index-upgrade.bin.gz` reads as missing | No action: accepted by the spec's Interactions section; the upgrade proof checks neither page |

A permission error reading as missing rests on `File.file?` returning false on a failed `stat`; no example forces one (not portable in CI).

## Distillation

2026-11-06 (`distill-feature`): the rules were written into [catalog operations](../../architecture/catalog-operations.md) (Glossary "Ready (art index)", the art index table's two Finished rows, the status-line paragraph, an accepted limit, Sources) and [release and deploy](../../architecture/release-and-deploy.md) (Neighbours line, the #122 limit reworded as fixed, Sources) in `fa3a0f4`; `fef8f9b` added both docs' Distillation log rows and set the index row to Frozen by both, plan retirement owed; `6aa432a` added the spec's frozen line. CLAUDE.md only points to the area doc and needed no change. No ADR is owed. The plan is retired after the merge.
