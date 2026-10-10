---
name: sdd-execute-exact-plans
description: Executing a long plan whose code blocks were pre-run — subagents read their phase's line range, apply blocks by script, and the result is diffed against the prototype branch
metadata:
  type: feedback
---

For a long plan whose blocks are byte-exact (written, run and replayed on a prototype branch first, as spec 015's 5,000-line plan was), give each implementer subagent its phase's line range of `plan.md` plus the header lines, and tell it to extract the blocks by script and `git apply` the diffs, never to retype them. Pasting the phase into the prompt only copies the file.

**Why:** in spec 015 (2026-10-10) ten phases landed this way with no code deviation, each subagent still seeing the stated failing run before the implementation. The only slips were extraction ranges (one diff applied twice, caught and reset by the subagent). This is the controller's reading of what worked; the maintainer didn't comment on the method.

**How to apply:** brief each subagent with the line range, "apply exactly", "take care that no diff is applied twice", and a whole-suite run at the end. After the last phase, check `git diff <prototype-branch> HEAD -- . ':!docs/specs' ':!docs/adr'` is empty before deleting the prototype branch. Related: [[subagent-commit-trailers]], [[plan-reviews-run-the-code]], [[work-ahead-of-human-checkpoints]].
