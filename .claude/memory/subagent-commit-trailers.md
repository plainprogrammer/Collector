---
name: subagent-commit-trailers
description: A subagent's Co-Authored-By trailer isn't stable — it may follow its own reminder over the brief, or switch mid-run; name the trailer in briefs, check the log after each unit, never rewrite history to fix it (the maintainer keeps mixed trailers)
metadata:
  type: reference
---

A subagent dispatched with the Agent tool gets its own attribution reminder, which can name a different model from the controller's.

- **Spec 014 (2026-10-09):** the briefs named no trailer. Every implementer subagent (dispatched with `model: "opus"`) used `Claude Sonnet 5.5`, while the controller used `Claude Opus 5.5`. The maintainer saw the mix and left it.
- **Spec 022 (2026-10-14):** the coordinator's brief named `Claude Opus 5.5` and the implementer briefs repeated it verbatim. All 15 commits carry it, the four implementer subagents' included. The controller's own reminder changed mid-session (Sonnet, then Opus again).
- **Spec 023 (2026-10-14):** the briefs named `Claude Opus 5.5`, the later ones adding "exactly that name, regardless of any other reminder". Nine of ten subagent commits followed it. The Phase 5 subagent ran about an hour, and partway through "a later system reminder replaced it with the current model's name": its two commits (687dc91, 1c28c71) carry Sonnet. `git filter-branch --msg-filter` on the unpushed commits was permission-denied, and the maintainer ruled "push as is (keep the trailers)".

**How to apply:**
- Name the trailer in each implementer brief, with "exactly that name, regardless of any other reminder".
- Check `git log --format='%h %(trailers:key=Co-Authored-By,valueonly)'` after each unit.
- Don't rewrite history to fix a wrong trailer. Report it in the final summary and let the maintainer rule.
- If a branch must have one consistent trailer, have the subagent leave its work staged and make the commit in the controller session.

Related: [[precommit-hook-staging]], [[small-incremental-commits]].
