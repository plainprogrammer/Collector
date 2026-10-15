# Verification: Spec 027

**Spec:** [spec.md](spec.md) v1.3.0 · **Plan:** [plan.md](plan.md) · **Branch:** `027-architecture-area-docs`

Every criterion of spec 027 is a prose criterion, verified by reading at the head and recorded here (`.claude/rules/testing.md`; spec D8). Comparisons "with the base" are with the merge base below.

## Baseline

- Merge base: `df611326b79a3907f3bb06e4ffca4c433e74a469` (`df61132`; `git merge-base origin/main HEAD`, 2026-10-15). The plan named `6b422d1`; `origin/main` was merged into the branch after the plan was written (PR #101, memory-only changes), which moved the merge base.
- CLAUDE.md at the base: 2,312 words (`git show df61132:CLAUDE.md`, then `wc -w`); its "Admin catalog and jobs" bullet (line 35, one line): 714 words.
- Own-plan Markdown links in the pilot's folders at the base (`git grep -n "](plan.md)" -- docs/specs/002-scryfall-catalog-search docs/specs/011-card-scanner-art-matching docs/specs/015-admin-catalog-and-jobs docs/specs/024-refresh-rate-limit-wait ':!.kamal/secrets'`), output:

  ```
  docs/specs/011-card-scanner-art-matching/research.md:3:**Spec:** [spec.md](spec.md) (v1.1.3) | **Plan:** [plan.md](plan.md)
  docs/specs/024-refresh-rate-limit-wait/verification.md:3:**Spec:** [spec.md](spec.md) v1.1.0 · **Plan:** [plan.md](plan.md) · **Date:** 2026-10-14
  ```

  That is `011-card-scanner-art-matching/research.md:3` and `024-refresh-rate-limit-wait/verification.md:3`, nothing else. `020-readme-introduction/verification.md:479` is a path in quoted `git` output, not a link, and is outside the pilot.
- Open issues bearing on catalog operations (`gh issue list --state open --limit 200 --json number,title,body`, 2026-10-15; 25 open issues, each title and body read):
  - [#77](https://github.com/plainprogrammer/Collector/issues/77) No way to start or cancel while a rate-limited job waits to retry: names the catalog refresh, the art build, `/admin/catalog` and `/admin/jobs`.
  - [#86](https://github.com/plainprogrammer/Collector/issues/86) Rate-limit retries count over a job's whole life, so a long build can run out: names the art index build and the catalog refresh.
  - [#41](https://github.com/plainprogrammer/Collector/issues/41) Back up and restore an instance: its body names the art index, saying the backup ADR decides whether the catalog downloads and the art index under `storage/catalog/` are included, since they can be rebuilt. Selected because AC-1.7 takes every issue whose body names the art index; it bears on catalog operations only through what a backup holds.

  No other open issue names the catalog refresh, the art build or art index, the admin catalog page or the jobs pages. #52 (the art margin on unseen cards) is about the scanner's match threshold, not the art build, and #23 (a comics catalog source) names no catalog operation.

## Phase 1: Rules and process docs

Commits: `198f39d` (area docs README), `c0ac6b0` (rule file), `8e86ff8` (steering file), `bc5d1ca` (memory and `MEMORY.md`), `e42f591` (git convention). Old state checked before each edit: `docs/architecture/`, `.claude/rules/documentation.md` and `.claude/memory/steering/architecture.md` didn't exist; the memory said "edit that spec in the same PR" and its `MEMORY.md` line (51) said "patch bump + changelog"; `docs/git-convention.md` had no `## Merging` heading.

- **AC-4.1** `docs/architecture/README.md`: purpose at line 3 ("One area doc per subsystem holds the current truth about it …"); area list `## Areas` lines 7–17, one row per D2 area, six marked "not written yet", and line 19 for specs 001, 003 and 014 ("CLAUDE.md", no area doc); the D5 shape `## The shape of an area doc` lines 21–32, the eight sections in order; when an area doc is updated `## When an area doc changes` lines 36–40 (FR-5: same pull request, Sources for an issue fix, Distillation log for a whole feature only, distilled before ready for review and retired after the merge, supersessions in the new spec and the index); links the specs index (lines 3 and 34), the ADR index (line 5) and the reference docs D2 names (design system, export format, releasing; lines 13, 16, 17). The links to `catalog-operations.md` and `../specs/README.md` resolve once Phases 2 and 4 add those files.
- **AC-4.2** `.claude/rules/documentation.md`: line 4 "A change to the behaviour, a constant or a rule of an area that has an area doc updates that doc in the same pull request"; line 9 "Don't edit a shipped spec, frozen or not, except for its frozen line, its retirement pointer and its links to its own retired plan, each in a commit of its own that names spec 027 D4"; line 5 "A change that supersedes part of a shipped spec records the supersession in its own spec … and in `docs/specs/README.md`, both directions, and updates the area doc where one covers that part"; line 6 names the distillation step ("then the `distill-feature` skill").
- **AC-4.3** `.claude/memory/steering/architecture.md` line 3: `loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-review` (same front matter form as `steering/roadmap.md`); line 10 "**Before writing** a PRD, spec or plan, read the area docs of the areas the feature touches"; line 11 "**In a spec or plan,** name the area docs the feature will change".
- **AC-4.6** `.claude/memory/edit-specs-your-change-makes-stale.md` line 8 "don't edit that spec. Record the supersession in the new spec … add it to `docs/specs/README.md` in both directions, and update the area doc"; line 10 names R3, R8 and specs 025 and 026; line 12 keeps the 2026-10-14 history (the maintainer's quote, spec 015 v1.3.1) as history. `MEMORY.md` line 51: "a shipped spec made stale → record the supersession in the new spec and the index, update the area doc; never edit the old spec (R3, R8, 2026-10-15; first used by specs 025, 026)". Neither tells an agent to edit an earlier spec.
- **AC-4.8** `.claude/rules/documentation.md` line 7: "Record a feature's implementation review (`sdd-review` Mode B) in its `verification.md` under a `## Implementation review` heading, with the verdict … on its first line. `distill-feature` reads that heading to know the feature is finished."
- **AC-5.1** `docs/git-convention.md` `## Merging` (line 31, after the front matter): line 33 "Pull requests are merged with a merge commit, never squashed or rebased …; the repository's settings allow merge commits only", and retired plans depend on it ("A retired plan is read back from the commit that deleted it …, spec 027 R6 and D7"); line 35 "Rebasing a branch before it merges changes the sha of every commit on it. On a branch that retires a plan, write the retirement pointer after the branch's last rebase".

Rulings:

- Ruling: the README's catalog operations row names 002 FR-3–FR-6 "and their Error Scenarios rows" — spec D2 and FR-4 include those rows and the draft dropped them — cost if wrong: one extra phrase in a table cell.
- Ruling: the README says "in the feature's own pull request", not "in its own pull request" — the draft could be read as a separate pull request, while FR-5 (ruling OD1) puts the distillation in the feature's pull request before it is marked ready — cost if wrong: none; the meaning is the spec's.
- Ruling: the memory's History paragraph keeps the maintainer's 2026-10-14 quote and the spec 015 v1.3.1 detail — AC-4.6 says the memory keeps its 2026-10-14 history as history, and the draft's summary dropped the quoted ruling — cost if wrong: two extra sentences in a memory file.
- Ruling: the git convention cites spec 027 "R6 and D7", not D7 alone — AC-5.1 asks that the section say retired plans depend on merge commits (R6) — cost if wrong: two words.
- Checked and unchanged: the `MEMORY.md` line to replace existed verbatim (line 51); the git convention's insertion point (end of the `### Commit messages` examples, after the front matter) exists; the steering front matter matches the other steering files (`scope`, `loaded-by`); `MEMORY.md` doesn't list steering files one by one, so the new steering file needs no index line.
## Phase 2: The catalog operations area doc

Commit: `5ae87d0` (`docs/architecture/catalog-operations.md`, new). Sources read in full or in the parts the plan names: spec 015 (all), spec 024 (all), spec 002 FR-3–FR-6 with Stories 4–8 and its Error Scenarios, spec 011 FR-1, FR-2, Story 3, Reliability and Error Scenarios, the bullet saved at the base (`bullet-base.md`, 714 words), ADR 0015, and every file the doc's Scope names (`app/models/catalog/{refresh,refresh_run,refresh/progress,operation,operation/queue,refresh_operation,health,failure_reason,sources}.rb`, `app/models/catalog.rb`, `app/jobs/catalog/*.rb`, `app/jobs/mtg/art/build_job.rb`, `app/models/mtg/{art,art_build}.rb`, `app/models/mtg/art/{build,operation,decoder}.rb`, `app/models/mtg/scryfall/{client,source}.rb`, the admin controllers and views, `app/helpers/admin_helper.rb`, `app/models/background_jobs/*.rb`, `app/javascript/controllers/poll_controller.js`, `lib/tasks/catalog.rake`, `config/recurring.yml`, `config/initializers/catalog.rb`, `spec/admin_catalog_core_spec.rb`).

### AC-1.1: headings

`grep -n "^## " docs/architecture/catalog-operations.md`: Scope (5), Glossary (22), Invariants (40), States and transitions (58), Named constants (144), Decisions not in an ADR (173), Sources (195), Distillation log (205). The D5 eight, in the D5 order, each with content; none is "None.". "Accepted limits and open issues" is a bold label inside Decisions not in an ADR, as `docs/architecture/README.md` item 6 says.

### AC-1.3: constants

Each row read against its definition at the head (`5ae87d0`).

| Constant | Value in the doc | Definition at the head | Match |
|---|---|---|---|
| `Catalog::RefreshRun::STALL_AFTER` | 15 minutes | `app/models/catalog/refresh_run.rb:6` `15.minutes` | yes |
| `Catalog::RefreshRun::JOB_ENDED_GRACE` | 2 minutes | `app/models/catalog/refresh_run.rb:13` `2.minutes` | yes |
| `Catalog::RefreshJob::LOCK_FOR` | 6 hours | `app/jobs/catalog/refresh_job.rb:7` `6.hours` | yes |
| `Catalog::Refresh::BATCH_SIZE` | 1,000 | `app/models/catalog/refresh.rb:6` `1_000` | yes |
| `Catalog::Refresh::Progress::EVERY_RECORDS` | 5,000 | `app/models/catalog/refresh/progress.rb:5` `5_000` | yes |
| `Catalog::Refresh::Progress::EVERY_SECONDS` | 2 | `app/models/catalog/refresh/progress.rb:6` `2` | yes |
| `Catalog::Refresh::Progress::AT_MOST_EVERY_SECONDS` | 1 | `app/models/catalog/refresh/progress.rb:7` `1` | yes |
| `Catalog::Health::RECENT_RUNS` | 5 | `app/models/catalog/health.rb:4` `5` | yes |
| `Catalog::RateLimitRetry::SHORTEST_WAIT` | 45 seconds | `app/jobs/catalog/rate_limit_retry.rb:19` `45.seconds` | yes |
| `Catalog::RateLimitRetry::LONGEST_WAIT` | 1 hour | `app/jobs/catalog/rate_limit_retry.rb:20` `1.hour` | yes |
| `Catalog::RateLimitRetry::MAX_RETRIES` | 3 | `app/jobs/catalog/rate_limit_retry.rb:21` `3` | yes |
| `MTG::ArtBuild::STALE_AFTER` | 10 minutes | `app/models/mtg/art_build.rb:8` `10.minutes` | yes |
| `MTG::ArtBuild::JOB_ENDED_GRACE` | 2 minutes | `app/models/mtg/art_build.rb:22` `2.minutes` | yes |
| `MTG::Art::Build::BATCH` | 50 | `app/models/mtg/art/build.rb:9` `50` | yes |
| `MTG::Art::Build::BEAT_EVERY` | 30 seconds | `app/models/mtg/art/build.rb:15` `30.seconds` | yes |
| `MTG::Art::Build::IMAGE_HOSTS` | `cards.scryfall.io` | `app/models/mtg/art/build.rb:17` `%w[cards.scryfall.io]` | yes |
| `MTG::Scryfall::Client::MIN_INTERVAL` | 0.1 | `app/models/mtg/scryfall/client.rb:21` `0.1` | yes |
| `MTG::Scryfall::Client::MAX_ATTEMPTS` | 3 | `app/models/mtg/scryfall/client.rb:22` `3` | yes |
| `MTG::Scryfall::Client::MAX_BACK_OFF` | 30 | `app/models/mtg/scryfall/client.rb:25` `30` | yes |
| `MTG::Scryfall::Client::RATE_LIMITED_FOR` | 30 | `app/models/mtg/scryfall/client.rb:28` `30` | yes |
| `MTG::Scryfall::Client::OPEN_TIMEOUT`, `READ_TIMEOUT` | 10, 60 | `app/models/mtg/scryfall/client.rb:29`, `:30` `10`, `60` | yes |
| `MTG::Scryfall::Source::KEEP_DOWNLOADS` | 2 | `app/models/mtg/scryfall/source.rb:7` `2` | yes |
| `BackgroundJobs::List::PER_PAGE` | 25 | `app/models/background_jobs/list.rb:6` `25` | yes |
| `poll` controller `interval` | 2,000 ms | `app/javascript/controllers/poll_controller.js:8` `default: 2000` | yes |

Every constant AC-1.3 names is a row, each with its reason. No mismatch. The reasons were checked against the comments at the definitions (`refresh_run.rb:4-13`, `refresh_job.rb:4-6`, `rate_limit_retry.rb:9-15`, `art_build.rb:9-21`, `build.rb:10-14`, `client.rb:23-28`) and the specs cited.

### AC-1.2: the bullet, statement by statement

The bullet at the base (`bullet-base.md`), split at each sentence and semicolon-separated clause.

| # | Statement at the base | Where the area doc states it |
|---|---|---|
| 1 | "Admin catalog and jobs (spec 015, ADRs 0014 and 0015)" | Sources (spec 015; ADRs 0014, 0015) |
| 2 | `/admin/catalog` renders `Catalog::Health` (one per registered type) and its `Catalog::Operation`s: the core's `Catalog::RefreshOperation`, plus whatever a source's optional `.operations` hook adds (`MTG::Art::Operation`) | Glossary "Operation"; States, refresh panel paragraph ("The page has one panel per registered type (`Catalog::Health.all`) … holding the refresh and then whatever the source's `.operations` hook adds") |
| 3 | the core code never names a collectible (`spec/admin_catalog_core_spec.rb`) | Invariants "The core never names a collectible" |
| 4 | A refresh run records its stage, progress, heartbeat and job id (`Catalog::Refresh::Progress`) | Glossary "Run", "Last progress / heartbeat"; States, refresh run, Running ("each write is also the heartbeat") |
| 5 | 15 minutes without progress is a stall (`Catalog::RefreshRun::STALL_AFTER`) | Glossary "Stalled"; Start step 1; panel table; Named constants |
| 6 | a running run whose own job the queue has failed, or no longer holds, is interrupted once it has made no progress for 2 minutes (`JOB_ENDED_GRACE`, issue #60) | Start step 1; panel row "Running, its job failed or gone …"; Named constants |
| 7 | `Catalog::RefreshOperation` reads the queue before the runs | Invariants "The queue is read before the runs" ("`Catalog::Refresh#call` and `Catalog::RefreshOperation` read it first") |
| 8 | and `Catalog::Refresh#call` reads Solid Queue's tables too, before it starts its run | same invariant; Start ("called by `Catalog::Refresh#call` with the queue it read first") |
| 9 | both are separate from the job's 6-hour queue lock (`Catalog::RefreshJob::LOCK_FOR`) | Decisions "The stall threshold is not the lock"; Named constants `LOCK_FOR` |
| 10 | A refresh run with a job id outside the queue (`Catalog::RefreshJob.perform_now` in a console) is judged the same way: it reads as interrupted, and a refresh that starts closes it, once it goes 2 minutes without progress | Start step 1 ("A run whose job id is outside the queue … reads interrupted, and a refresh that starts closes it") |
| 11 | The art build follows the same rule in its own code (issue #73): a running `MTG::ArtBuild` is left behind once its heartbeat is older than 10 minutes (`STALE_AFTER`), or older than 2 minutes (`MTG::ArtBuild::JOB_ENDED_GRACE`, its own constant, set by how often the build beats) when the queue has failed its job or no longer holds it | States, art build, Start (`#left_behind?`); Named constants `STALE_AFTER`, `JOB_ENDED_GRACE` ("The build's own constant, set by how often it beats") |
| 12 | The build beats after every batch of 50 artworks and, inside a batch, after an image once 30 seconds have passed (`MTG::Art::Build::BEAT_EVERY`) | States, art build, Running; Named constants `BATCH`, `BEAT_EVERY` |
| 13 | so only one image that takes more than 90 seconds by itself leaves a working build quiet that long | Named constants `BEAT_EVERY` ("only one image that by itself takes more than 90 seconds can") and `MTG::ArtBuild::JOB_ENDED_GRACE` (30 + 60 = 90); Accepted limits (a working build "while one image takes more than 90 seconds") |
| 14 | The Scryfall client's waits for a rate limit can't do that alone: a wait before a retry is 30 seconds at most (`MTG::Scryfall::Client::MAX_BACK_OFF`, issue #74) | A rate-limited job, step 1; Named constants `MAX_BACK_OFF`, `MTG::ArtBuild::JOB_ENDED_GRACE` |
| 15 | so one call sleeps 60 seconds at most | A rate-limited job, step 1 |
| 16 | and a longer wait asked for, a 429 on the last of 3 attempts, or a 429 with no usable `Retry-After` on any attempt (issue #81: it isn't retried in the call; a `Retry-After` of zero counts as none) raises `Catalog::Sources::RateLimitedError` | A rate-limited job, step 1 |
| 17 | That error stops the art build (its run fails; no image is counted as failed) | States, art build, Ends |
| 18 | and `Catalog::RateLimitRetry` makes `Catalog::RefreshJob` and `MTG::Art::BuildJob` run again no sooner than the source asked (45 seconds at least, which is the 30 Scryfall says a 429 limits access for plus a margin; an hour at most, 3 such retries, then the job fails) | A rate-limited job, step 2; Named constants `SHORTEST_WAIT`, `LONGEST_WAIT`, `MAX_RETRIES` |
| 19 | `MTG::ArtBuild#left_behind?` is the one statement of it, asked by `MTG::Art::Operation`, `MTG::Art.status_line` and `MTG::ArtBuild.start!`, each of which reads the queue's build jobs before the build | States, art build, the paragraph after Ends; Invariants "The queue is read before the runs" |
| 20 | The panel and the status line ask `MTG::ArtBuild#stalled?` first (issue #79) | same paragraph |
| 21 | a build whose heartbeat is older than 10 minutes while a worker still holds its own job is stalled, not interrupted, and reads "Building, no heartbeat for N minutes" with the advice to restart the app, the button disabled and the page polling, as a stalled refresh does | Glossary "Stalled"; art section table, row "Heartbeat older than `STALE_AFTER`, its job still claimed"; Decisions "Stalled is not interrupted" |
| 22 | a build job that starts closes it all the same | States, art build ("A build job that starts closes a stalled build all the same"); Start ("whether or not a worker holds its job") |
| 23 | While a failed build's own job waits in the queue to run again (a rate limit, a busy database), the panel reads "Queued to retry. The last build failed. …" with a "Retrying at" fact (issue #80) | art section table, row "Failed build whose own job is scheduled to run again" |
| 24 | `Catalog::Operation::Queue#retry_at` takes the job's id | same row ("`Catalog::Operation::Queue#retry_at` takes the job's id") |
| 25 | and a build queued fresh reads "Queued." | art section table, row "A build job in the queue that isn't a failed build's own retry" |
| 26 | A refresh or art build that starts while another job of the same operation (for a refresh, of the same type) waits in the queue to run again is skipped, manual or scheduled (`waiting for another job's retry`, `Catalog::Operation::Queue#waiting_to_retry?`, issue #78) | Glossary "Waiting retry"; refresh Start step 3; art build Start; A rate-limited job, step 3; Decisions "Skip, not defer" |
| 27 | it asks the source nothing, and the waiting job does the work | refresh Start step 3; A rate-limited job, step 3 |
| 28 | A failed refresh or build says why in a plain sentence, never an error's class name (issue #84): `Catalog::FailureReason` derives it at display time from the stored `"<error class>: <message>"` | Invariants "A failure is shown as a plain sentence" |
| 29 | (the core words `Catalog::Sources` errors and a busy database; a source words its own through the optional `.failure_reasons` hook, as `MTG::Scryfall::Source` does for ImageMagick missing) | same invariant (the MTG sentence is its own, per AC-1.6) |
| 30 | and the panel keeps the stored text as a "Technical detail" fact | same invariant; panel tables |
| 31 | `catalog:status` and the log print the stored text unchanged | same invariant |
| 32 | "In flight" and the jobs pages (`BackgroundJobs::List`, `BackgroundJobs::Entry`) read Solid Queue's own tables | Glossary "In flight" (`Catalog::Operation::Queue`); Invariants "The jobs pages read Solid Queue's own tables"; Scope |
| 33 | Pages poll with the `poll` Stimulus controller only while work is in flight | Invariants "Pages poll only while work is in flight"; States, Polling |
| 34 | In specs, Solid Queue's tables are loaded into the test database (`spec/support/solid_queue.rb`) | Left out: kept in CLAUDE.md (Phase 3); it is a test-setup fact an agent needs before it knows where to look (R5), not a rule of the area |
| 35 | tag an example `:solid_queue` to queue through Solid Queue (no worker runs) and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job` | Left out: kept in CLAUDE.md (Phase 3), as 34 |

No statement of the bullet is untrue at the head. Two needed care against the draft: 22 (the draft's `#left_behind?` said "unless a worker still holds its job", which is `#stalled?`'s display rule, not the start guard's; corrected, see Corrections) and 10 (the draft said a console run had no job id; corrected).

### AC-1.4: the sources, item by item

"Stated" names the doc section; "changed since" gives the change and its source, and the doc states the changed form; "not in this area" names the area.

**Spec 015 Glossary**

| Item | Result |
|---|---|
| Catalog type | stated (Glossary) |
| Operation (refresh, extra operation) | stated (Glossary) |
| Loaded (per type; search adopts it) | stated (Glossary; Decisions "Loaded means an applied run"); search's use is catalog core |
| In flight | stated (Glossary) |
| Queued (operation state) | stated (Glossary; panel tables) |
| Interrupted (stall, own job, failed or gone after 2 minutes; art build's own record and threshold) | stated (Glossary "Left behind / interrupted"; refresh and art Start) |
| Stalled (shown as running; art build with its 10-minute threshold; a starting job closes it all the same) | stated (Glossary; art paragraph after Ends; refresh Start step 1) |
| Stages of a refresh | stated (Glossary) |
| Job states on the jobs page | stated (Glossary) |
| Admin / member | stated (Glossary) |

**Spec 015 FR-1 – FR-8**

| Item | Result |
|---|---|
| FR-1 record stage, done/total, counts | stated (refresh Running) |
| FR-1 cadence of AC-2.9, by records and time, not rows changed | stated (refresh Running; Invariants "Progress is written outside…") |
| FR-1 keep the stage reached on failure | stated (refresh Ends) |
| FR-1 record the job id; close a run with the starting job's own id | stated (refresh Start step 1) |
| FR-1 judge by job after 2 minutes; queue read before the runs | stated (Start step 1; Invariants) |
| FR-1 15-minute stall for display and start guard | stated (Start step 1; Named constants) |
| FR-1 keep the 6-hour lock | stated (Decisions; Named constants) |
| FR-1 must not: progress inside batch transactions | stated (Invariants) |
| FR-1 must not: change finished counts or the already-applied skip | stated (refresh Running, Ends: unchanged rules) |
| FR-2 optional download and sync progress; sources without it keep working | stated (refresh Running; source section) |
| FR-2 optional extra operations with title, state, progress, summary, startable, how to queue | stated (Glossary "Operation"; panel paragraph; Scope `Catalog::Operation`) |
| FR-2 implement both for MTG | stated (source section, `#progress=`; art section) |
| FR-2 must not: core knows a source by name | stated (Invariants "The core never names a collectible") |
| FR-3 queue the existing job with the same arguments | stated (Invariants "Starting from the page bypasses no guard") |
| FR-3 refuse in flight or unavailable, and say so | stated (panel paragraph; art paragraph after the table) |
| FR-3 redirect (see other) with a notice | stated in substance (the notices); the status code is a Rails convention (`.claude/rules/hotwire.md`) |
| FR-3 must not: run inline, call the source in a request or render | stated (Invariants) |
| FR-3 must not: bypass the start guards | stated (Invariants) |
| FR-4 keep pages current by re-rendering, about 2 seconds | stated (Polling; Named constants `interval`) |
| FR-4 stop when nothing is in flight | stated (Polling) |
| FR-4 must not: broadcast from jobs | stated (Invariants) |
| FR-5 read the queue's own records | stated (Invariants; Jobs pages) |
| FR-5 retry and discard failed jobs only, through the queue's operations | stated (Invariants; Jobs pages) |
| FR-5 confirm a discard on its own page | stated (Jobs pages) |
| FR-5 must not: pause, bulk, act on non-failed | stated in its current form (only failed jobs have actions; Jobs pages); pause and bulk don't exist |
| FR-5 must not: more than 25 per page | stated (Named constants `PER_PAGE`) |
| FR-6 not-loaded notices, naming types when more than one | stated (Not-loaded notice); changed since for visitors by spec 023 decision 7 (first sentence only), stated in that form |
| FR-6 never queue a refresh except start request, schedule, rake | stated (Invariants "Nothing queues a refresh by itself") |
| FR-7 admin guard, 404 for members | stated (Invariants "Admins only") |
| FR-7 link from the More page for admins | stated (Jobs pages, last sentence) |
| FR-7 design-system components; document new patterns | not in this area: the UI rule in CLAUDE.md and `docs/design-system/` |
| FR-7 must not: accept class, queue or method names | stated (Invariants "The jobs pages read…") |
| FR-8 absolute UTC times | stated (Decisions "Times") |
| FR-8 relative form | stated (Decisions "Times") |

**Spec 015 Error Scenarios**

| Row | Result |
|---|---|
| Scryfall download fails mid-way | stated (refresh Ends: failed with the stage; the job's retry rules; Jobs pages) |
| Bulk file unreadable | stated (refresh Ends, `no valid records`) |
| App restarts during a refresh | stated (Decisions "A graceful restart re-runs, a crash fails"; Start step 1) |
| Queue fails the job of a refresh still working | stated (Accepted limits, second item) |
| App restarts during an art build | stated (Decisions, graceful restart; art Start) |
| Queue fails the job of a still-working art build, or `perform_now` | stated (art Start, console sentence; Accepted limits; Named constants `JOB_ENDED_GRACE`, `BEAT_EVERY`) |
| Two admins press "Refresh now" at once | stated (panel paragraph, AC-2.3; Decisions "Two queued manual refreshes both apply") |
| No download progress and more than 15 minutes | stated (panel row, stalled) |
| A worker hangs (refresh) | stated (Decisions "Stalled is not interrupted") |
| A worker hangs during an art build | stated (art table, stalled row; Decisions) |
| Image host rate limits, or a busy database | stated (art Ends; art table "Queued to retry"; Accepted limits, third item) |
| Retry or discard of a job already handled | stated (Jobs pages) |
| A job's class no longer exists | stated (Jobs pages) |
| ImageMagick missing | stated (art Ends; Invariants, failure sentence) |
| Expected download size unknown | stated (panel row "Running…", no percentage) |

**Spec 024**

| Item | Result |
|---|---|
| Decision 1, skip not defer (ruled), and what skip gives up | stated (refresh Start step 3; Decisions; Accepted limits, fourth item) |
| Decision 2, manual as scheduled (ruled) | stated (Start step 3; Decisions) |
| Decision 3, any waiting retry counts, however far off | stated (Decisions) |
| Decision 4, the check in the start guard after closing left-behind runs; its own message; not "the" run; a skipped build shows nowhere; a running run wins; the art build's window | stated (Start steps 1–3; panel paragraph; art Start; Accepted limits, first item) |
| Decision 5, the starting job's own retry doesn't count | stated (Start step 3; Glossary; Decisions) |
| Decision 6, two waiting retries | stated (Decisions) |
| FR-1 `Queue` answers "held for later, other than this id" | stated (Glossary "Waiting retry") |
| FR-2 `RefreshRun.start!` records `WAITING_FOR_RETRY` after closing left-behind runs, a running one still gives "already running" | stated (Start steps 2–3) |
| FR-3 `attempted` leaves out both skips | stated (panel paragraph) |
| FR-4 `ArtBuild.start!` makes the same check, its own constant | stated (art Start) |
| FR-5 retry rules unchanged | stated (A rate-limited job, step 2: the rules as they stand) |

**Spec 002 FR-3 – FR-6**

| Item | Result |
|---|---|
| FR-3 adapter behind `Catalog::Sources` | stated (Scope; Invariants, hooks) |
| FR-3 discover the bulk file, its version; `default_cards` for English only | stated (source section) |
| FR-3 download in the background, verify, keep two | stated (source section; Named constants `KEEP_DOWNLOADS`); the check at the head compares the size Scryfall publishes |
| FR-3 read record by record | stated (source section) |
| FR-3 filter languages and digital-only | stated (source section) |
| FR-3 map records; skip and count malformed, log their id | stated (refresh Running); the mapping itself is catalog core |
| FR-3 load sets; a missing set made from the printing's code and name | stated (refresh Running) |
| FR-3 API terms: headers, 100 ms, bounded back-off, timeouts, no-wait 429 | stated (source section; A rate-limited job, step 1; Named constants) |
| FR-3 must not: called during a request | stated (Invariants) |
| FR-3 must not: per-card API requests in a refresh | stated (source section) |
| FR-4 background, at most one per type | stated (Invariants "Two refreshes of one type never apply at once") |
| FR-4 record type, version, trigger, status, times, counts, error | stated (Glossary "Run", "Trigger"; refresh Ends) |
| FR-4 skip a scheduled already-applied run; never a manual one | stated (refresh Running) |
| FR-4 one run per attempt | stated (refresh statuses line) |
| FR-4 "younger than 6 hours … skipped; older … interrupted" | changed since: spec 015 AC-3.3 and #60 (15-minute stall, own-job rule, 2-minute job rule); the doc states the current rule and the change (Start steps 1–2). Its waiting-retry clause (spec 024) is stated (step 3) |
| FR-4 write only changed rows | stated (Invariants "A refresh writes only what changed") |
| FR-4 retire after a complete file; restore | stated (same invariant) |
| FR-4 retire only after full processing | stated (same invariant) |
| FR-4 short write transactions | stated (same invariant; Named constants `BATCH_SIZE`) |
| FR-4 rate-limit retry: 45 s floor, 1 hour, 3 retries, before transient retries, holds for every refresh of the type | stated (A rate-limited job, steps 2–3; Named constants) |
| FR-4 must not: delete; change an entry's identity | stated (same invariant) |
| FR-5 weekly refresh in production | stated (Glossary "Trigger"; Invariants, first item; Scope) |
| FR-5 command to queue a manual refresh | stated (panel paragraph, `catalog:refresh`) |
| FR-5 command printing the 10 most recent runs | stated (panel paragraph, `catalog:status`) |
| FR-5 one structured log entry per finished run | stated (refresh Ends, `catalog.refresh.finished`) |
| FR-6 a documented setting, English always | stated (source section) |
| FR-6 default English only | stated (source section) |
| FR-6 reject unknown codes before download | stated (source section) |

**Spec 002 Error Scenarios**

| Row | Result |
|---|---|
| Bulk-data index unreachable or times out | stated (A rate-limited job, step 1: an API call raises at once; refresh Ends: the job's retry rules) |
| 429 with a `Retry-After` of 1 to 30 seconds | stated (A rate-limited job, steps 1–2) |
| 429 with no usable `Retry-After`, or zero | stated (steps 1–3; refresh panel "Queued to retry") |
| 429 with a `Retry-After` over 30 seconds | stated (steps 1–3) |
| More than an hour, or a fourth rate limit | stated (step 2) |
| File fails its integrity check | stated (source section) |
| File can't be decoded or parsed | stated (refresh Ends, `no valid records`, no retirements) |
| One malformed record | stated (refresh Running) |
| Process killed or deployed mid-refresh ("6+ hours later") | changed since: spec 015 AC-3.3, Error Scenarios and #60; stated in its current form (Start step 1; Decisions, graceful restart) |
| Refresh triggered while one is running ("younger than 6 hours") | changed since: spec 015 AC-3.3, AC-3.4 and #60; stated in its current form (Invariants; Start steps 1–2) |
| Invalid language code | stated (source section) |
| Unknown printing, unknown card's printings page, page number, unknown set code | not in this area: catalog core (search and card pages) |
| Catalog never loaded ("Search page shows 'not loaded yet'") | changed since: spec 015 FR-6 (search, scanner and the More page, by role) and spec 023 decision 7 (visitors); stated in that form (Not-loaded notice) |

**Spec 011 FR-2 (the build's run) and Story 3**

| Item | Result |
|---|---|
| FR-2 store artwork id and `small` URI in the MTG extension; artwork table, build runs, cache global | not in this area: scanner (the columns and the table) and CLAUDE.md "Catalog data is global" (global data) |
| FR-2 reach the MTG extension only through the two generic source steps of AC-2.4 | stated (Invariants, hooks `#reapply?`, `#after_refresh`; refresh Running) |
| FR-2 write artwork data only through the build job, after a refresh, in batches | stated (Invariants, first item; art build) |
| FR-2 idempotent, resumable, incremental | stated (art Running) |
| FR-2 external data rules for images | stated (source section; A rate-limited job, step 1; Named constants `IMAGE_HOSTS`, `MIN_INTERVAL`) |
| FR-2 update CLAUDE.md's "only through `Catalog::Refresh`" note | stated as the rule it added (Invariants, first item) |
| FR-2 must not: fetch in a request, on boot, or with art matching off | stated (Invariants, first item) |
| FR-2 must not: art concepts in the core | stated (Invariants, core) |
| AC-3.1 when a build is queued | stated (art build intro) |
| AC-3.2 the guard, job id, heartbeat, staleness, own-job and job-ended rules | stated (art Start, Running) |
| AC-3.4 the image request | stated (source section; A rate-limited job, step 1) |
| AC-3.5, AC-3.7, AC-3.8 cache, fingerprints, resume | stated (art Running) |
| AC-3.6 failed images; a rate limit stops the build; the job's retry | stated (art Running, Ends; A rate-limited job) |
| AC-3.9 the index written last, previous kept | stated in part (art Ends; "never removes the index in use"); the file's format is scanner |
| AC-3.3, AC-3.10 which image, decoder agreement | not in this area: scanner |
| AC-3.11 `catalog:status`'s art line | stated (art paragraph after the table) |

### AC-1.5: Sources and their links

Sources links specs 002 (FR-3, FR-4, FR-5, FR-6, Error Scenarios), 011 (FR-2 and Story 3, the build's run), 015 (all) and 024 (all), spec 023 (decision 7 only), ADRs 0014, 0015 and 0018, and issues #60, #61, #73, #74, #78, #79, #80, #81, #84 and the open #41, #77, #86. Every relative link in the doc was checked with `test -e` from `docs/architecture/`: the four spec files, spec 023's, the three ADRs and `../design-system/components/MorePage.md` exist; `../specs/README.md` resolves once Phase 4 adds it. Each issue checked with `gh issue view <n> --json number,state,title` (2026-10-15): #60, #61, #73, #74, #78, #79, #80, #81, #84 exist (closed); #41, #77, #86 exist (open).

### AC-1.6: no collectible in a statement about the core

`git grep -n -w -i -e MTG -e Scryfall -e Art -- docs/architecture/catalog-operations.md ':!.kamal/secrets'` at `5ae87d0`: 45 lines (3, 10, 12, 13, 24, 25, 27, 31, 35, 42, 44, 47, 48, 55, 91, 93, 95, 97, 99, 101, 105, 106, 116, 118, 120, 121, 123, 128, 129, 159–169, 179, 187, 193, 197, 198). Each read:

- 3 (intro): names the MTG art index build as one of the area's subjects; no statement about `Catalog::` code.
- 10, 12, 13 (Scope): the items naming `MTG::Scryfall::*`, `MTG::Art*`, `MTG::Art::Operation`; the `Catalog::` classes in item 13's list are listed, not described.
- 24 (Glossary "Catalog type"): `config/initializers/catalog.rb` registers `mtg`; a statement about the configuration, not `Catalog::` code.
- 25, 27, 31, 35 (Glossary): the sentences naming `MTG::Art::Operation`, `MTG::ArtBuild`, an art build's heartbeat, `MTG::Art::Build#call`; the `Catalog::` part of each is a separate clause naming no collectible.
- 42, 44, 47, 48, 55 (Invariants): each hit is in its own sentence about `MTG::Art::BuildJob`, `MTG::ArtBuild.start!`, `MTG::Art::Operation`, `MTG::Art.status_line` or `MTG::Scryfall::Source`; the draft sentences that named both (42, 44, 48) were split for this check, and 55's is its own sentence.
- 91–116 (States, art build): every hit is about `MTG::ArtBuild`, `MTG::Art::*` or art matching.
- 118–123 (States, the source): about `MTG::Scryfall::Source` and Scryfall's bulk data.
- 128, 129 (A rate-limited job): step 1 is about `MTG::Scryfall::Client`; in step 2 the hit is the separate sentence "… and so does `MTG::Art::BuildJob`"; the sentences about `Catalog::RateLimitRetry` name no collectible ("the source").
- 159–169 (Named constants): the `MTG::` rows and their reasons; the `Catalog::RateLimitRetry::SHORTEST_WAIT` row says "the one source so far", as its definition does.
- 179 (Decisions): an art build and a refresh don't wait out each other's limit; about the art build.
- 187 (#41): the art index under `storage/catalog/`.
- 193, 197, 198: link paths (`002-scryfall-catalog-search`, `011-card-scanner-art-matching`) and the Distillation log; no statement about `Catalog::` code.

No statement about `Catalog::` code names a collectible. The "core never names a collectible" invariant says "no collectible's, source's or operation's name" rather than quoting the three checked words.

### AC-1.7: open issues

Command at the head: `gh issue list --state open --limit 200 --json number,title,body`, 2026-10-15: 33 open issues. Since the Baseline (25), #102–#109 were opened for this feature (#102 its tracking issue, #103 YARD, #104–#109 the slice C area docs); their bodies were searched for refresh, art, build, admin and jobs and name none of the catalog operations. A filter over every title and body for `refresh|art build|art index|admin/catalog|admin catalog|/admin/jobs|jobs page` (case-insensitive) selects #86, #77 and #41, the Baseline's list. All three are under "Accepted limits and open issues", each with its link, and in Sources' open issues. #41 is stated only as what it says about catalog operations' data (whether a backup holds the catalog downloads and the art index, which can be rebuilt); the doc adds no behaviour any of the three would add (#77's start or cancel, #86's progress-based count, #41's backup).

### Corrections to the draft (FR-2: the code at the head decides)

1. **Art build left behind.** Draft: "`#left_behind?`: heartbeat older than `STALE_AFTER` unless a worker still holds its job". Code: `app/models/mtg/art_build.rb:58`, `:72` (`left_behind? = stale? || (quiet? && job_ended?)`) and `:40` (`.start!` closes any build that is `left_behind?`): a stale build is left behind whether or not a worker holds its job; "unless a worker holds" is `#stalled?` (`:64`), the display rule. Spec 015 Glossary "Stalled" agrees ("a refresh or an art build job that starts closes a run past its threshold whether or not a worker holds its job"). Corrected in States, art build, Start.
2. **Console refresh runs.** Draft: "A run with no job id (a refresh run in a console with `perform_now`) is judged the same way". Code: `perform_now` gives the run a job id that no queue row holds, so `Catalog::RefreshRun.job_gone` (`refresh_run.rb:66-68`) and `RefreshOperation#job_gone?` (`refresh_operation.rb:119`) judge it by the 2-minute job rule; a run with no job id is excluded (`where.not(job_id: [nil, …])`) and judged only by `STALL_AFTER`. The bullet (statement 10) and spec 015 AC-3.3 agree. Corrected in Start step 1.
3. **Core boundary.** Draft: "`app/models/catalog/`, `app/jobs/catalog/` and the admin catalog controllers and views contain no whole word `MTG`, `Scryfall` or `Art`". At the head `git grep -n -w -i -e MTG -e Scryfall -e Art -- app/models/catalog app/jobs/catalog ':!.kamal/secrets'` finds four comments: `app/jobs/catalog/refresh_job.rb:2` (the rake task's example `catalog:refresh[mtg]`), `app/models/catalog/entry.rb:1`, `:8`, `app/models/catalog/identity.rb:1` and `app/models/catalog/sources.rb:2` (examples of a source and its records). `spec/admin_catalog_core_spec.rb:6-10` checks 15 named files (the page's controllers and views, `operation`, `operation/*`, `refresh_operation`, `health`, `refresh/progress`, `failure_reason`, the not-loaded partial, `AdminHelper`, the `poll` controller), and none of them names one. Sources disagree: spec 015 AC-5.4 is about the admin catalog code; spec 024's NFR "Core boundary" says `app/models/catalog/` and `app/jobs/catalog/` name no collectible. The code decides: the invariant states what is checked, and that elsewhere in those folders only comments name a collectible, as an example. No code logic in those folders names one.
4. **"Queued to retry" wording.** Draft: "Queued to retry. The last build failed: …"; spec 015 AC-4.12 and spec 024's Goals quote `failed: <message>`. Code: `MTG::Art::Operation#summary` (`art/operation.rb:61`, `:117`) reads `Queued to retry. The last build failed. <sentence>` since #84; the bullet says the same. Corrected, with "changed by #84".
5. **Spec 002 FR-3–FR-6 belong here.** The draft's Neighbours gave "what a refresh writes … the source contract's data methods" to catalog core. Spec 027 D2 (and `docs/architecture/README.md`) assigns 002 FR-3–FR-6 to catalog operations and FR-1, FR-2, FR-7–FR-10 to catalog core. The doc now states FR-3's download, filtering and request rules (new section "What the source does for a refresh"), FR-4's write rules (Invariants), FR-5's tasks and log, and FR-6's languages; Neighbours keeps the records, the name index, the mapping and search in catalog core.
6. **Missing from the draft, added after the AC-1.4 walk:** the hooks `#reapply?` (spec 011 AC-2.3; `refresh.rb:76`) and `.status_lines` (spec 011 AC-3.11; `catalog.rake:21`); the not-loaded notice (spec 015 FR-6, AC-1.1–AC-1.3; spec 023 decision 7; `_not_loaded.html.erb`, shown on the More page to admins only, `mores_controller.rb:4`); admin-only access (FR-7); per-type panels and 404s (AC-5.1–AC-5.6); the jobs pages' notices and finished or class-less jobs (AC-6.5–AC-6.7); the empty, never, skipped and applied panel rows (AC-1.4, AC-2.13, AC-2.14); the build job recording nothing with art matching off or before the first applied refresh (`art/build.rb:35-38`); the start notices (AC-2.3, AC-4.4); and the constants `BATCH_SIZE`, `IMAGE_HOSTS`, `MIN_INTERVAL`, `RATE_LIMITED_FOR` and `KEEP_DOWNLOADS`.
7. **Refresh panel text.** The panel's failed and interrupted summaries read `Failed while <doing>. <sentence>` and `Interrupted while <doing>.` (`refresh_operation.rb:62`, `:133`, `DOING` at `:6`); the "Queued to retry" form is `The last run failed while <doing>. <sentence>` (`:59`). The draft's "The last run failed …" is kept in that fuller form.
8. **Failed-list link on a failed run or build.** `failed_job?` for a failed run or build asks whether any job of the operation is under Failed (`operation.rb:53`, `refresh_operation.rb:47`, `art/operation.rb:56`), not that run's own job; only an interrupted one is judged by its own job. The doc says "when a refresh job for the type is there" / "when a build job is there" for the failed rows.
9. **#41** added under "Accepted limits and open issues" and to Sources (controller ruling; AC-1.7).
10. **Distillation log** row names the open issues too; its PR cell stays "spec 027's pull request" until Phase 8 (controller ruling).

### Code with no spec source

- `app/javascript/controllers/poll_controller.js:6`, `:19-20`: the `poll` controller skips a tick while the tab is hidden, while Turbo is busy (`aria-busy`) and while a menu (`details[open]`) is open. No spec, ADR or issue states it (spec 015 FR-4 and ADR 0015 describe only the interval and stopping). Stated in the doc's Polling section marked "(no spec source; see `verification.md`)". Listed for the controller; no issue opened.

No behaviour was found that every source contradicts.

## Phase 3: CLAUDE.md and the frozen lines

Commits: `fc50021` (CLAUDE.md), `3a85ae4` (spec 002 frozen line), `cbb9c2e` (spec 011), `5abfb32` (spec 015), `ad8afa4` (spec 024). Old state checked before each edit: CLAUDE.md line 35 began `- **Admin catalog and jobs (spec 015, ADRs 0014 and 0015):**` (one match), line 9 held ``Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.`` verbatim, and `wc -w CLAUDE.md` gave 2312; none of the four specs contained "Frozen". The plan's drafts were used as written; no ruling was needed.

- **AC-2.1** The bullet (CLAUDE.md line 35) was copied to `<scratchpad>/bullet-head.md`; `wc -w` output: `54 …/bullet-head.md` (at most 60). It links [`docs/architecture/catalog-operations.md`](../../architecture/catalog-operations.md), and keeps the `:solid_queue` tag and the helpers `queue_job`, `claim_job`, `fail_job`, `finish_job` (each defined in `spec/support/solid_queue.rb`, lines 17, 23, 31, 40).
- **AC-2.2** Line 9 now reads ``Current rules per subsystem: `docs/architecture/` (area docs). Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/` (index: `docs/specs/README.md`).`` It names `docs/architecture/` as the current rules per subsystem and `docs/specs/README.md` as the specs index (that file arrives in Phase 4).
- **NFR Performance** `wc -w CLAUDE.md` output: `1661 CLAUDE.md`, 651 fewer than 2,312 (at least 630 required). The bullet went from 714 words to 54; the opening list gained 9 words (2,312 − 714 + 54 + 9 = 1,661; at most 20 allowed).
- **AC-2.3** `git diff df61132 -- CLAUDE.md`: `1 file changed, 2 insertions(+), 2 deletions(-)` in two hunks, `@@ -6,7 +6,7 @@` (line 9, the opening list of documents) and `@@ -32,7 +32,7 @@` (line 35, the bullet). Nothing else changed.
- **Frozen lines (FR-4, D4)** Each line is the last line of its spec's header block, after `**Branch:**` (specs 002, 011) or `**Issue:**` (specs 015, 024) and before the blank line and `---`. `git diff df61132 -- docs/specs/002-scryfall-catalog-search/spec.md docs/specs/011-card-scanner-art-matching/spec.md docs/specs/015-admin-catalog-and-jobs/spec.md docs/specs/024-refresh-rate-limit-wait/spec.md` shows exactly four added lines, one per file, and no removed line:

  ```
  docs/specs/002-scryfall-catalog-search/spec.md  @@ -5,6 +5,7 @@
  +**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (parts: FR-3–FR-6 and their Error Scenarios rows); see the [specs index](../README.md)
  docs/specs/011-card-scanner-art-matching/spec.md  @@ -5,6 +5,7 @@
  +**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (parts: FR-2, the art build's run); see the [specs index](../README.md)
  docs/specs/015-admin-catalog-and-jobs/spec.md  @@ -6,6 +6,7 @@
  +**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (whole spec); see the [specs index](../README.md)
  docs/specs/024-refresh-rate-limit-wait/spec.md  @@ -6,6 +6,7 @@
  +**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (whole spec); see the [specs index](../README.md)
  ```

  No version, changelog row or other text changed. The `../README.md` link resolves once Phase 4 adds the specs index.

## Phase 4: The specs index
## Phase 5: The distillation step
## Phase 6: Plan retirement
## Phase 7: Roadmap, ADR index and issues
## Phase 8: Integration verification
