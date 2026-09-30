# Memory Index

- [Foundation](foundation.md) — mission and principles, loaded every session
- [Small incremental commits](small-incremental-commits.md) — one Conventional Commit per step/change
- [Secret files are user-verified](secret-files-user-verified.md) — agents are read-denied on secrets/storage; ask the user to cat them
- [SDD review model choice](sdd-review-model-choice.md) — reviews on Fable via subagent; planning on Opus in-session
- [Scryfall API access](scryfall-api-access.md) — docs 403 to WebFetch; use curl + User-Agent; bulk JSONL facts
- [PR screenshots workflow](pr-screenshots-workflow.md) — headless Firefox + magick/ffmpeg; embed in private-repo PRs via blob/<sha>?raw=true
- [Background servers via task](background-servers-via-task.md) — run_in_background + TaskStop, not &/kill/pkill
- [Branch naming convention](branch-naming-convention.md) — NNN-slug (no type prefix) per docs/git-convention.md, even in differently named worktrees
- [Headless Firefox narrow frame](headless-firefox-narrow-frame.md) — windows can't go below 500px; test/screenshot phone widths in a fixed-width iframe
- [Pre-commit hook staging](precommit-hook-staging.md) — hook reads the command text for `git add` / `commit -a`; stage separately to be safe
- [Reproduce CI with its seed](reproduce-ci-with-seed.md) — on CI failure, run the full suite with the CI seed as an early reproduction step
- [Turbo Back navigation quirks](turbo-back-navigation-quirks.md) — two restore paths, snapshots keep form values, stale aria-busy; url-sync + wait_for_turbo_idle
- [PR #5 follow-ups](pr5-open-followups.md) — after merge: stale aria-busy decision pending, back-button flake watch, uncaptured failure
- [Card scanner direction](card-scanner-direction.md) — maintainer is going ahead after Phase 0 (PR #6); spec Phase 1 from research.md §8; corpus in ~/card-scanner-corpus
- [Phone LAN dev access](phone-lan-dev-access.md) — 192.168.1.76, firewall already open for high ports, bind 0.0.0.0; iPhone uses Brave (WebKit); camera needs HTTPS
- [Work ahead of human checkpoints](work-ahead-of-human-checkpoints.md) — in sdd-execute, run maintainer-independent units first; record rulings in commit bodies
