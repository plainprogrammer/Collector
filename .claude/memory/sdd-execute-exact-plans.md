---
name: sdd-execute-exact-plans
description: Executing a plan whose code blocks were pre-run — one subagent per phase even for a small plan (maintainer, 2026-10-11); subagents read their phase's line range and apply blocks by script; how to build and revise the prototype branch
metadata:
  type: feedback
---

For a long plan whose blocks are byte-exact (written, run and replayed on a prototype branch first, as spec 015's 5,000-line plan was), give each implementer subagent its phase's line range of `plan.md` plus the header lines, and tell it to extract the blocks by script and `git apply` the diffs, never to retype them. Pasting the phase into the prompt only copies the file.

**Why:** in spec 015 (2026-10-10) ten phases landed this way with no code deviation, each subagent still seeing the stated failing run before the implementation. The only slips were extraction ranges (one diff applied twice, caught and reset by the subagent). This is the controller's reading of what worked; the maintainer didn't comment on the method.

**How to apply:** brief each subagent with the line range, "apply exactly", "take care that no diff is applied twice", and a whole-suite run at the end. After the last phase, check `git diff <prototype-branch> HEAD -- . ':!docs/specs' ':!docs/adr'` is empty before deleting the prototype branch. Related: [[subagent-commit-trailers]], [[plan-reviews-run-the-code]], [[work-ahead-of-human-checkpoints]].

**Maintainer's feedback (2026-10-11, spec 018, relayed by the Orca coordinator at the session wrap):** use one subagent per phase as `sdd-execute` prescribes, even for a small plan. In spec 018 the five phases were executed in the main session instead: each phase's spec files were checked out from the prototype commit, seen red, then its implementation files, seen green, and committed. The code came out byte-identical to the plan, but that is what happened there, not an approved method. Don't repeat it: a brief that allows reusing prototype commits doesn't waive the subagent per phase.

**Building the prototype branch (spec 018, 2026-10-11; my method, not commented on by the maintainer):**
- Prototype in the worktree, then replay it as one local commit per phase on a scratch branch (`NNN-plan-phases`), never pushed.
- Fold a review fix into its phase with `git commit --fixup=<phase commit>`, then `GIT_SEQUENCE_EDITOR=true git rebase --autosquash <base>`. The phase commits get new ids, so the plan is rendered again afterwards.
- Record each phase's true red: check out the previous phase's commit, `git checkout <phase> -- <its spec files>`, run them, then undo with `git restore --source=HEAD --staged --worktree -- <those files>`. `git reset --hard` and `git clean` are denied by `.claude/settings.json`, and a command containing them is refused whole.
- Render the plan from the commits by script: a new file whole (`git show <commit>:<path>`), a changed file as `git diff <commit>^ <commit> -- <path>`. Keep the template and the script in the scratchpad so a revision is one more render.
- After any fold, run the whole suite again before rendering. Related: [[css-shell-state-by-class]].
