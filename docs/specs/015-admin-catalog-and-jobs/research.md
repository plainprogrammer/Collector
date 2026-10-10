# Research Notes: Admin Catalog Operations and Jobs

Manual checks from plan Phase 9, run once on 2026-10-10 and not part of CI.

**Machine:** the development machine (Intel Xeon E3-1270 v3, 4 cores, Linux), development environment, SQLite.
**Catalog:** MTG, English only, 106,846 cards from `default-cards-20261010090604` (a 78.8 MB download). Art matching off.
**Commit:** `b115cd2`.

## Benchmark 1: page render (NFR Performance)

**Target:** `/admin/catalog` and `/admin/jobs` render in under 300 ms with a loaded MTG catalog and 1,000 finished, 100 failed and 100 scheduled jobs in the queue. **Met.**

The queue held the plan's 1,200 stand-in jobs (plus two real, finished refresh jobs). Each page was loaded six times in headless Firefox by a signed-in admin; the first load is left out as a warm-up. Times are the `Completed 200 OK in …` lines of `log/development.log`.

| Page | Load 1 | Load 2 | Load 3 | Load 4 | Load 5 | Queries |
|------|--------|--------|--------|--------|--------|---------|
| `/admin/catalog` | 66 ms | 80 ms | 54 ms | 49 ms | 51 ms | 11 |
| `/admin/jobs` | 60 ms | 59 ms | 42 ms | 47 ms | 48 ms | 15 |

The stand-ins were removed afterwards (1,200 rows deleted).

## Benchmark 2: progress overhead (NFR Performance)

**Target:** recording progress adds no more than 5% to a refresh's wall-clock time, measured on a re-run that changes nothing. **Met.**

With the development server stopped, a manual refresh of the already applied version was timed with progress writes and with `Catalog::Refresh::Progress#write` replaced by a no-op. The plan's script runs each once; here they alternate three times after one warm-up, because one pair's difference is inside the run-to-run noise. Every run applied and saw 106,846 records.

| Pair | With progress | Without progress writes |
|------|---------------|-------------------------|
| 1 | 19.53 s | 19.28 s |
| 2 | 19.20 s | 19.25 s |
| 3 | 19.33 s | 19.35 s |
| Mean | 19.35 s | 19.29 s |

Ratio of the means: 1.003, an overhead of about 0.3%.

## A real refresh, watched in a browser

On an empty development database, in headless Firefox:

- Search showed "The card catalog hasn't been loaded yet. Go to the catalog page to load it." and `/admin/catalog` showed the empty state with "Refresh now", without polling.
- After "Refresh now" the button was disabled at once and the page began polling. The stages advanced by themselves: Download, then Sync cards from 2% to 97% with the counts rising about every 2 seconds, then Rebuild name index, then "Applied." with 106,846 seen and inserted. The whole run took 70 seconds.
- When the run ended the page dropped its poll controller and re-enabled the button. After a later run, the browser made no request in the 8 seconds that followed.
- Not seen: the download's percentage bar (the download took under 2 seconds, less than one poll) and the Retire missing cards stage (it passed between two polls). Both are covered by the request specs.
- Not checked: art matching on (`COLLECTOR_MTG_ART_MATCHING=true`), whose first build is about 708 MB and 2.6 hours of fetching; the art index section showed the "off" text.

## A restart mid-refresh

"Refresh now" was pressed and the server stopped when the sync reached 30%. The stop was not graceful: the job stayed claimed and its run stayed running at 57,527 seen. So this checked the crash path, not the graceful one.

- After the restart, the catalog page read "Running." at 53% with "Refresh now" disabled, and the jobs page listed the job under Running.
- About 5 minutes after the worker's last heartbeat, Solid Queue failed the job with `SolidQueue::Processes::ProcessPrunedError`, and it listed under Failed with its error.
- "Retry" on the job's page answered "Retrying Catalog::RefreshJob." Within 3 seconds the earlier run was listed as "failed · interrupted" and a new run was syncing; it applied in 21 seconds (106,846 seen, 0 changed) (AC-3.3).
- Not checked: a graceful restart, where the queue puts the job back by itself.

## The pages, looked at

Screenshots are in [screenshots/](screenshots/), taken in headless Firefox at 1280px and, in a fixed-width frame, at 390px, in light and dark. At 390px no page scrolled sideways (document width 378px in a 390px frame, on every page and state shot). Not checked: focus rings.

| State | Shots |
|-------|-------|
| Not loaded | `01-search-not-loaded`, `02-catalog-empty`, `03-catalog-empty-phone` |
| Refresh running | `04-refresh-syncing`, `05-refresh-rebuilding-index` |
| After the crash (run still reads running) | `06-refresh-after-crash-dark`, `07-refresh-after-crash-phone-dark` |
| The failed job | `08-jobs-failed`, `09-jobs-failed-dark`, `10-job-failed`, `11-job-failed-phone`, `12-discard-confirm`, `13-discard-confirm-phone-dark` |
| A full queue (the benchmark's stand-ins) | `14-jobs-failed-100`, `15-jobs-failed-100-phone-dark`, `16-jobs-scheduled` |
| Applied | `17-catalog-applied`, `18-catalog-applied-dark`, `19-catalog-applied-phone`, `20-catalog-applied-phone-dark` |
| Other | `21-jobs-empty`, `22-job-finished`, `23-more-phone`, `24-search-loaded` |

## Notes for later

- **For a later spec:** a run whose job crashed less than 15 minutes ago still reads "Running." with no pointer to the failed job until the stall threshold passes, which is what the spec asks. Seen here: from the job failing until it was retried about a minute later, the catalog page said "Running." with "Refresh now" disabled while the job sat under Failed (`06-refresh-after-crash-dark`).
- **For the upgrade notes:** a refresh interrupted by the upgrade to this version isn't resumed by its re-queued job, because a run recorded before the upgrade has no job id. It reads as running for up to 15 minutes, then as interrupted, and "Refresh now" then works.
- **Attempts reads 0 for a job the queue failed.** A job's page shows the executions count Active Job keeps, which rises only on Active Job's own retries. The refresh job that the queue failed as pruned, and that an admin retried, read "Attempts 0" throughout (`22-job-finished`). The spec asks for "attempts (executions)", so this is as specified, but it may surprise an admin.
