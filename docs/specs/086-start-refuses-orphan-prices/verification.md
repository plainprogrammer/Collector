# Verification: spec 086, a start refuses a volume that holds a prices database and no primary (#375)

**Spec:** v0.3.2 · **Plan:** Approved (Gate B) · **Branch:** `086-start-refuses-orphan-prices`

## Evidence per criterion

Suite examples are in `spec/lib/collector/start_check_spec.rb` (class level, `StartCheck.refusal` on a scratch volume) and `spec/start_check_spec.rb` (process level: the real `bin/docker-entrypoint` run with `echo ./bin/rails server` as its command, so its condition matches and its `exec` runs `echo`). AC-1.3, 1.4, 1.7, 1.8 and 2.4 are proven at class level; the wiring is proven once by AC-1.1 and AC-1.5, which run the real entrypoint.

| AC | Evidence | Status |
|---|---|---|
| AC-1.1 | `spec/start_check_spec.rb` (status 1, standard output empty, standard error equals the three lines, the directory's files and checksums unchanged) | proven |
| AC-1.2 | `spec/lib/collector/start_check_spec.rb` (one `include` per sentence); `spec/start_check_spec.rb` (exact standard error, no trace) | proven |
| AC-1.3 | class spec (each sidecar alone, its full path named) | proven at class level |
| AC-1.4 | class spec (an empty file; a file holding junk) | proven at class level |
| AC-1.5 | process spec (a real SIGKILL at the restore's `prices_placed` checkpoint, then the entrypoint refuses; the placed prices file keeps its three rows) | proven |
| AC-1.6 | process spec (`RAILS_ENV=production`, no `SECRET_KEY_BASE`, a wrong master key: the message, not a secret error) | proven |
| AC-1.7, AC-1.8 | class spec (an empty primary, a dangling-symlink primary, a primary sidecar; each named with what it is and listed to remove; the prices path named) | proven at class level |
| AC-2.1 | process spec (an empty directory: status 0, both configured databases created; the five on the image are AC-4.2's) | proven in the suite |
| AC-2.2, AC-2.3 | process spec (primary and prices; primary only, prices created) | proven |
| AC-2.4 | class spec (queue, cache and cable files only) | proven at class level |
| AC-2.5 | process spec (`echo hello`, not a server start, passes through on the refused volume); `spec/lib/collector/backup/restore_spec.rb` (a second restore refuses the volume itself) | proven (a regression guard: green before the change by design) |
| AC-2.6 | `spec/start_check_spec.rb` (the task has no `:environment` prerequisite; no boot file, initializer, environment file or `app/` file names the check, comment lines and the `autoload_lib(ignore:)` line left out) | proven |
| AC-2.7 | process spec (removal, then a new instance; removal, restore again onto the volume, then a start with the restored rows) | proven |
| AC-3.1 | `restore_spec.rb` (exact advice text, red before the change) | proven |
| AC-3.2 | read, below | proven by reading |
| AC-4.1, AC-4.2 | `bin/backup-smoke`'s new leg | image run recorded below |
| AC-4.3 | `bin/backup-smoke collector:branch collector:main` (the restore image is an image of `origin/main`) | image run recorded below |

## Decision 7's measure

A bare Active Record connection to a new scratch primary (`bin/rails runner` in a child, `app_command`) leaves **4096 bytes**, one page, and no sidecar file (the class spec's measure example asserts it is more than 0). The premise of the spec review's round 2 M1 holds: only an empty file (a `touch`, a bare open) and a dangling link are covered by the "primary is there" rule; any one-off command that connects through the application disarms the check, which the Non-Goals and Error Scenarios say. No spec text changed.

## Documents read (AC-3.2)

Each says that a start refuses the volume, and none says only "never start" or that #375 "will" refuse it: `README.md` (Restore, "If a restore was interrupted"), `docs/backup-restore.md` (the killed-restore paragraph), `docs/releasing.md` (an upgrade note), `docs/architecture/release-and-deploy.md` (the server-start rule and its citation `bin/docker-entrypoint:6-9`, the killed-restore rule, the smoke rule, Sources, the issues line), `docs/architecture/prices.md` (Sources), `docs/roadmap.md` (the #375 row: done), `CLAUDE.md` (Project Status clause and the Release and deploy bullet's spec list). A `git grep -n -i "never start\|don.t start\|#375"` outside `docs/lessons/`, spec 081 and ADR 0029 finds no stale statement; the area doc's distillation-log row keeps its historical "(#375)".

## Deviations

- **AC-4.1 "foreground":** the smoke leg runs the refused container detached with a bounded wait (`$attempts` polls of 2 s), not in the foreground. An image that doesn't refuse starts a server that never exits, and a foreground run would hang the CI job until its timeout instead of failing at the leg and naming the spec (plan review M2). The leg asserts the exit status is exactly 1, so a kill is not taken for the refusal.
- **Process examples nest in one top-level group** (`RSpec/MultipleDescribes`), and `killed_child` is defined again beside the entrypoint examples because `restore_spec`'s is a `let` in that file.

## Implementation review

SPEC-ALIGNED WITH FINDINGS (Opus 5.5, read-only, 2026-11-13; 0 blocking, 1 major, 11 minor). The major finding, a missing `verification.md`, is this file. Fixed in `9438f2bb`: the smoke leg prints the restore's output on failure and the AC-4.2 line on a failing `runner`, and greps more of the message; the message names the prices file by its full path and words several leftovers plainly; the README names a leftover primary file; the class spec asserts the prices path for AC-1.8; the plan's Risks line without an example is dropped. Not changed, by choice: AC-1.5's "the placed file" rests on a row count and unchanged checksums, which is adequate. AC-4.1 to AC-4.3 await the image runs.
