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
## Phase 2: The catalog operations area doc
## Phase 3: CLAUDE.md and the frozen lines
## Phase 4: The specs index
## Phase 5: The distillation step
## Phase 6: Plan retirement
## Phase 7: Roadmap, ADR index and issues
## Phase 8: Integration verification
