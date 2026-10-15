---
date: 2026-10-14
spec: "022, 023, 024"
tags: [orchestration, parallel-work, git, planning]
---

# Lesson: Plan parallel workers by file overlap

## Context

On 2026-10-14 the maintainer asked for three issues to be supervised in parallel with Orca and one run as a subagent. They became #38 (export, spec 022), #59 (signed-out catalog, spec 023), #78 (a refresh waits out another's rate limit, spec 024) and #84 (plain failure messages). All four reached draft PRs (#95–#98) the same day.

## What happened

- **Picking by touched files kept the wave clean.** Issues #77, #78 and #86 all change `Catalog::RateLimitRetry` and the admin operations, and #64 (currency per account) would raise the export format while #38 was writing it. Only #78 went into the wave; the others were held back. The remaining overlap, #84 and #78 both changing `Catalog::Refresh`, the operations' summaries and CLAUDE.md's admin paragraph, was named up front, and #84 kept its edits out of `refresh.rb` entirely by working out the sentence when shown.
- **Numbers were reserved before anyone started.** Specs 022, 023 and 024 were assigned in the briefs, and ADR 0021 was given to #38 only, with any other worker told to ask. No worker took another's number (compare [[adr-numbers-across-branches]], where it happened).
- **The overlapping pair was stacked, not merged later.** At the push gate the maintainer had #78 rebased onto #84's branch and opened as a draft PR based on it (#96 on #95), so the conflict was resolved once, by the worker that knew both changes, before review.
- **The shared documents still conflict.** Every branch adds a line to `docs/roadmap.md` and most change `CLAUDE.md`; the session-wrap memories went into a separate memory PR so that `.claude/memory/` files edited by three workers didn't become three conflicting versions.

## What to do next time

- Before choosing parallel work, list the files each candidate will change (from the issue bodies and a grep) and pick a set with no shared code files. Hold back the rest, however ready.
- Reserve spec and ADR numbers in the briefs.
- Where two chosen items share files, decide the merge order up front, and stack the later one on the earlier at its first push.
- Expect trivial conflicts in the roadmap and CLAUDE.md, and collect memories several workers want to edit into one memory PR.

## Signals to watch for

- Two candidate issues that name the same class or file in their bodies.
- A candidate that changes a format, schema or shared document another candidate reads.
- Several workers proposing updates to the same memory file in their session wraps.
