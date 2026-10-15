---
name: distill-feature
description: Use at the end of every session, right after sdd-superpowers:session-wrap, to distil a finished feature into its area docs before its pull request is ready, or to retire the plan of a feature whose pull request has merged. Says "nothing to do" otherwise.
---

# Distil a feature

Keeps `docs/architecture/` current and retires plans (spec 027 D6 and D7; rules in `.claude/rules/documentation.md`). `.claude/CLAUDE.md`'s session-end instruction runs it after `session-wrap`. It has three states. Check them in this order and act on the first that applies: the after-merge check comes first because it can apply on any branch.

Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; end every `git grep` with `':!.kamal/secrets'`. In an isolated worktree, run one git operation per Bash call, and `git add` and `git commit` in separate calls. Every commit ends with the session's Co-Authored-By trailer.

**Never change a shipped spec beyond spec 027 D4:** its `**Frozen:**` line, its retirement pointer, and plain-text replacements of its links to its own retired plan, each in a commit whose message names "spec 027 D4". No typo fixes, no "superseded" notes, no version bump. Supersessions go in the index.

What the index (`docs/specs/README.md`) says, and the words this skill reads and writes there:

- Columns: `Spec`, `Status`, `Areas`, `Plan`, `Supersedes`, `Superseded by`.
- Status: Draft, Approved, Shipped, Frozen in part, Frozen. A frozen row names its area doc: `Frozen, by [catalog operations](../architecture/catalog-operations.md)`, or `Frozen in part: <parts>, by [<area>](../architecture/<doc>.md)`.
- Plan: present, retirement owed, retired, none. A retired row's cell reads ``retired in `<sha>`; `git show <sha>^:docs/specs/NNN-<slug>/plan.md` ``.
- A row **shows its spec distilled** when its Plan is "retirement owed" or retired, or, for a spec with no plan (Plan "none"), when its Status is Frozen or Frozen in part.

A spec's pull request is found from its head branch: the spec's `**Branch:**` header line (it can differ from the folder name, as spec 002's `feat/002-scryfall-catalog-search` does), or the current branch. `gh pr list --head <branch> --state merged --json number,mergeCommit` lists it once merged. If `gh` can't answer (offline, not signed in), say so and ask the maintainer instead of guessing.

## 1. After the merge: retire owed plans

First check the pointers already there: for each sha in a "retired in `<sha>`" cell of `docs/specs/README.md`, run `git cat-file -e <sha>` (one call each). If one fails, warn the maintainer: the commit that deleted that plan isn't in this clone's history (a squash or rebase merge got through, or the clone is shallow), and the pointer needs rewriting to the commit that removed the plan from `main` (for a squash, `git show <squash sha>^:<path>`), recorded in that step's `verification.md` (spec 027 Error Scenarios). Carry on with the rest.

Then, for each row whose Plan is "retirement owed", find its pull request as above. A row qualifies only when that pull request has merged and `docs/specs/NNN-<slug>/plan.md` still exists on the current branch (if it's gone, it was retired here already). A row whose pull request hasn't merged (spec 027's own row on its own branch, for example) doesn't qualify. A spec with nothing to distil, such as 027, is retired the same way as any other.

For each qualifying row:

1. Make sure the branch you are on will merge into `main` with a merge commit and won't be rebased afterwards (`docs/git-convention.md`, Merging). A housekeeping branch from `origin/main` is the usual place; ask the maintainer before creating one. If an open pull request already retires this plan, say so and skip the row.
2. Delete `docs/specs/NNN-<slug>/plan.md` in a commit that changes nothing else: `git rm -q docs/specs/NNN-<slug>/plan.md`, then `git commit -m "docs(specs): retire the plan of spec NNN"`.
3. Read that commit's sha (`git rev-parse HEAD`). Call it `<sha>`.
4. In a second commit (spec 027 D7), with `<sha>` and the path filled in:
   - In the spec, directly under its `**Frozen:**` line (or as the header's last line if it has none):

     ```text
     **Plan:** retired in `<sha>`; read it with `git show <sha>^:docs/specs/NNN-<slug>/plan.md`
     ```

   - In the index row, set Plan to ``retired in `<sha>`; `git show <sha>^:docs/specs/NNN-<slug>/plan.md` ``, and Status to Shipped if it was Approved.
   - Replace every Markdown link to `plan.md` in the spec's folder (`git grep -n -E "\]\((\./)?plan\.md" -- docs/specs/NNN-<slug> ':!.kamal/secrets'`) with the plain text ``plan (retired in `<sha>`; read it with `git show <sha>^:docs/specs/NNN-<slug>/plan.md`)``. A path in quoted command output isn't a link; leave it.
   - Change nothing else in the spec. Commit: `docs(specs): point to the retired plan of spec NNN (spec 027 D4)`.
5. Check: `git show <sha>^:docs/specs/NNN-<slug>/plan.md` prints the plan, and `git show --stat <sha>` lists only the deleted plan.

If no row qualifies, go to 2.

## 2. Before the merge: distil the branch's feature

Applies when all of these hold:

- the current branch is `NNN-<slug>` (or names spec NNN in its spec's `**Branch:**` line) and a folder `docs/specs/NNN-*` exists;
- its pull request hasn't merged. A pull request needn't exist yet: the wrap runs before `gh pr create`;
- its index row doesn't show it distilled (above). Spec 027's own row reads "retirement owed", so on its branch this state doesn't apply;
- the feature is finished.

The feature is finished when `docs/specs/NNN-<slug>/verification.md` has a `## Implementation review` section whose verdict, on its first line, says aligned (for example "SPEC-ALIGNED"). Many spec folders have no `verification.md`, and older ones have no such section. If the section is missing, the file is missing, or the verdict is unclear, ask the maintainer whether the feature is finished; if it isn't, go to 3.

1. Read the spec, the plan, the `verification.md`, and the area docs of every area the index lists for the spec (`docs/architecture/README.md` has the list of areas and docs).
2. For each area with a doc: write into it what the feature established or changed, in the doc's own sections (its shape is in `docs/architecture/README.md`), each statement with its source inline (spec NNN AC-x, ADR, issue). Remove or rewrite statements the feature made untrue. Add the spec to Sources and one Distillation log row (date, what was distilled, the pull request: its number once opened, otherwise "spec NNN's pull request").
3. For an area without a doc: write nothing there; its slice of spec 027's follow-ups will distil it. Say so in the summary.
4. A decision of lasting weight that isn't in an ADR: propose an ADR to the maintainer; don't write it without their go-ahead.
5. In `docs/specs/README.md`: set the row's Status to Frozen or Frozen in part (in the forms above, naming the parts and area docs) where area docs now cover it, and its Plan to "retirement owed"; add the spec's supersessions in both directions (the other row's Supersedes or Superseded by cell).
6. If CLAUDE.md restates a rule the feature changed, replace the statement with a pointer to the area doc.
7. Commit the area docs, the index and CLAUDE.md: `docs(architecture): distil spec NNN into <area docs>`.
8. For a spec covered in whole or in part, add its frozen line as its header's last line, in a commit of its own: ``**Frozen:** the current rules are in [`<doc>.md`](../../architecture/<doc>.md) (whole spec | parts: …); see the [specs index](../README.md)``, one line naming every area doc that covers it. Commit: `docs(specs): mark spec NNN frozen by the <area> area doc (spec 027 D4)`.
9. Record what was distilled in the feature's `verification.md` and commit it.

Don't edit any other spec (`.claude/rules/documentation.md`).

## 3. Nothing to do

Applies when neither 1 nor 2 does: no plan is owed a retirement whose pull request has merged, and the branch names no spec, or the maintainer says its feature isn't finished, or its row already shows it distilled. Say "distill-feature: nothing to do" with the reason in one line, and stop. For example, on spec 027's branch before its merge: "distill-feature: nothing to do — spec 027's row already reads retirement owed and its pull request hasn't merged."
