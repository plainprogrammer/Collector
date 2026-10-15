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
## Phase 3: CLAUDE.md and the frozen lines
## Phase 4: The specs index
## Phase 5: The distillation step
## Phase 6: Plan retirement
## Phase 7: Roadmap, ADR index and issues
## Phase 8: Integration verification
