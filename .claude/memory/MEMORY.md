# Memory Index

- [Foundation](foundation.md) — mission and principles, loaded every session
- [Small incremental commits](small-incremental-commits.md) — one Conventional Commit per step/change
- [Secret files are user-verified](secret-files-user-verified.md) — agents are read-denied on secrets/storage; ask the user to cat them
- [SDD review model choice](sdd-review-model-choice.md) — reviews on Fable via subagent; planning on Opus in-session
- [Scryfall API access](scryfall-api-access.md) — docs 403 to WebFetch; use curl + User-Agent; bulk JSONL facts
- [PR screenshots workflow](pr-screenshots-workflow.md) — headless Firefox + magick/ffmpeg; embed in private-repo PRs via blob/<sha>?raw=true
- [Background servers via task](background-servers-via-task.md) — run_in_background + TaskStop, not &/kill/pkill
- [Branch naming convention](branch-naming-convention.md) — feat/NNN-slug per docs/git-convention.md, even in differently named worktrees
- [Headless Firefox narrow frame](headless-firefox-narrow-frame.md) — windows can't go below 500px; test/screenshot phone widths in a fixed-width iframe
- [Pre-commit hook staging](precommit-hook-staging.md) — hook reads the command text for `git add` / `commit -a`; stage separately to be safe
