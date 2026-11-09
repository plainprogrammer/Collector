# Feature 056: New and Changed Public Code Carries a Comment (a YARD Ratchet in `bin/ci checks`)

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `056-yard-comment-ratchet`
**Issue:** [#264](https://github.com/plainprogrammer/Collector/issues/264), the follow-up to [#103](https://github.com/plainprogrammer/Collector/issues/103) (spec 054, [ADR 0027](../../adr/0027-yard-for-api-documentation.md)). The maintainer asked for this spec on 2026-11-09
**ADR:** open (OD6)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-09 | Written from issue #264, `.claude/rules/code-documentation.md` (the guidance the check enforces), spec 054 and ADR 0027, and a spike of YARD 0.9.45's registry on the current code (Problem Statement). The decisions the issue lists "for the spec to decide" are decisions 1–5 below, each a recommendation for the maintainer to rule on (Open Questions OD1–OD6) |

---

## Problem Statement

[ADR 0027](../../adr/0027-yard-for-api-documentation.md) kept documentation **coverage** out of `bin/ci`: at 53.7% of objects documented, a gate on the total "would need comments written for their own sake", and it said a later spec may add a check. `.claude/rules/code-documentation.md` asks that code **added or changed** carries a comment (the why, and for reusable code a summary, `@param`, `@return`), but nothing checks it; only a reviewer can notice that a new public method has none, and nobody is asked to look. The rule's own line is "apply these rules to code you add or change; don't retrofit untouched files just to comply", which is exactly the scope of a check that looks only at what a branch changed.

A spike of YARD 0.9.45's registry on the current code (nothing committed) measured what such a check would see:

- Public objects (classes, modules, methods, constants; attribute methods counted as methods) and how many have no comment text: `app/models` 1,088 and 454; `lib` 355 and 146; `spec/support` 243 and 110; `app/controllers` 158 and 98; `app/helpers` 69 and 26; `app/jobs` 15 and 8; `app/mailers` 1 and 1. A total gate would fail on about 840 objects today; a check on what a branch changes fails on none of them.
- Every object has a file and a line (`file`, `line`), and 3 have two locations (a reopened class). The registry gives an object's first line but not its last, so the extent of a method must come from the source.
- A comment of tags only (`# @return [Integer]`) is "not blank" to YARD, and a method that overrides a documented one has an empty docstring of its own (nothing is inherited at the registry level). A method marked `# @api private` with no text is "blank". An `attr_reader` gets generated text ("Returns the value of attribute x."), so it is never blank. These are the places where "has a comment" needs a stated meaning (decisions 2 and 3).
- No object carries `@api private` today, so nothing needs exempting for that reason.

### Glossary

- **Scoped files:** the Ruby files the check judges (decision 1).
- **Judged object:** a public class, module or method (instance or class) in a scoped file (decision 3).
- **Changed object:** a judged object the branch added or changed (decision 4).
- **Summary:** the comment's text before its first tag. A comment of tags alone has no summary.
- **The base:** the commit the branch is compared with (decision 5).

## Goals

- `bin/ci checks` fails when the branch adds or changes a judged object that has no summary, and names each such object with its file and line.
- The check looks only at what the branch changed: code the branch doesn't touch is never judged, so `main` passes whatever its coverage, and the codebase's documentation grows only as code is touched.
- It runs in the places `bin/ci checks` runs (the pre-push hook for documentation-only branches, `bin/ci`, GitHub's checks job) with no new configuration there.

## Non-Goals

- **Total coverage:** no percentage, no list of every undocumented object, no gate on the codebase as a whole (ADR 0027).
- **The quality of a comment:** whether it says the why, whether it is stale after the code changed, whether `@param` and `@return` are present and right. A check can't tell; those stay with reviews, as `.claude/rules/code-documentation.md` says ("Keeping comments true") (decision 2, decision 5's reporting).
- Writing or retrofitting comments on code the branch doesn't touch, beyond what this branch's own changes need to pass the check.
- Controllers, jobs, mailers, channels, `app/javascript` and any file outside the scoped paths (decision 1).
- Private and protected methods, constants, and attribute methods (`attr_reader`, `attr_writer`, `attr_accessor`) (decision 3).
- An allowlist, a baseline file or an inline "skip" marker. A comment, or `@api private` (decision 3), is the only way past the check.
- Changing YARD's own step (`bin/yard doc`), the site, `.yardopts`, or the warnings rule of spec 054.
- Type annotations (`@param [Type]`).

## Users and Context

**Primary users:** the maintainer and agents (Claude Code sessions) who add or change Ruby code and open the pull request.
**Secondary users:** reviewers, who no longer have to look for a missing comment on a new public method.
**Usage context:** a contributor runs `bin/ci` (or its checks group) before pushing, or sees the check fail in the pull request; the failure names each object and file and line to fix.
**User mental model:** "if I add or touch a public method or class in the reusable code, it needs a comment saying what it is for"; the check is the rule in `.claude/rules/code-documentation.md` made mechanical for its easiest part.

## Decisions

### 1. Which files are judged (recommendation, OD1)

**Recommendation:** Ruby files under `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/` and `spec/support/`: the "reusable code" the rule lists (concerns, helpers, `lib/`, plain Ruby objects under `app/models/`, query methods and scopes, `spec/support/` helpers). Controllers, jobs, mailers and channels are entry points that the framework calls and the routes and area docs describe; their actions would be commented for their own sake. `spec/support/` is not part of the YARD site (`.yardopts` has `app` and `lib`), so the check parses its own file list and the site is unchanged.

**Alternatives:** (a) the issue's minimum, `app/models/` and `lib/` only; (b) all of `app/`, `lib/` and `spec/support/`. The spike's counts above show what each would put in reach: (b) adds 158 + 15 + 1 public controller, job and mailer objects.

### 2. What counts as "has a comment" (recommendation, OD2)

**Recommendation: a summary, any non-empty text before the first tag.** A comment of tags alone (`@return [Integer]`) is not a comment for this check, because the rule asks first for "a one-line summary saying what it gives the caller". `@param` and `@return` are **not** required: at 54% coverage most methods have no comment at all, a one-liner such as `def full_name = …` doesn't need them, and a check demanding them would produce comments for their own sake (ADR 0027). The rule's wording stays "reusable code gets `@param` and `@return`"; it is enforced by review.

**Alternative:** also require `@param` for each parameter and `@return` on methods with parameters, as the issue floats. The check can read the method's parameters from YARD; it would flag a method whose summary is fine because a tag is missing.

### 3. Which objects are judged, and `@api private` (recommendation, OD3)

**Recommendation:** public classes, modules and methods (instance and class methods, including `class << self`). Not judged: private and protected methods, constants, and attribute methods (`attr_*`, which YARD documents on its own; the rule asks constants to carry their why, which a reviewer checks, and a check on every constant would flag lists of symbols). **An object marked `@api private` counts as commented**, with or without text: the rule tells the author to mark one-caller helpers that way, so the mark is the comment's answer to "is this meant for reuse", and requiring text as well would make the mark pointless.

**Alternative:** `@api private` objects are judged like any other (they need a summary too); or constants are judged.

### 4. What "changed" means (recommendation, OD4)

A **method** is changed when the branch adds, edits or removes a line between its `def` line and its `end` (a one-line `def x = y` counts as one line); a method the branch adds counts as changed. A **class or module** is changed when the branch adds, edits or removes a line of its **opening** (the `class Foo < Bar` or `module Foo` line, `Foo = Struct.new(…)` and the like, which add a class); a branch that edits a method inside it does not change the class. So adding a new class asks for its comment, and editing one method of an old undocumented class asks only for that method's comment.

**Recommendation** is that member edits don't pull in the enclosing class: touching a line of a 600-line model would otherwise demand a class comment as the price of any fix, which the rule's "don't retrofit untouched files just to comply" argues against. **Alternative:** any change inside a class or module changes it; the first edit to each old class then writes its comment, which ratchets faster and makes small fixes cost more.

The diff is the branch's working tree against the base, with renames followed: a file moved with no edit changes nothing; an edited moved file is judged on its edited lines only. An untracked file is entirely added. A deleted file or object is never judged. A change that only reformats a method (a RuboCop autocorrect inside it) is a change.

### 5. The base, and when it can't be found (recommendation, OD5)

**Recommendation:** the base is the merge base of `HEAD` and `origin/main` (as `Collector::PushScope` finds the branch's changed paths for the pre-push hook, spec 035 decision 3). In GitHub's checks job (`fetch-depth: 0`) that is `main`'s tip for a pull request, so the check judges the pull request's own changes; on `main` itself (a push after a merge) the merge base is `HEAD`, nothing has changed, and the check passes. After a merge of `main` into the branch the merge base is the newest `main` commit in the branch's history, so what `main` brought in is not judged, only the branch's own changes. **When the base can't be found** (no `origin/main` ref, no merge base, a detached checkout with no history) **the check fails** and says what to fetch, instead of passing: a check that silently passes where it can't see is the failure mode `PushScope`'s FR-4 avoids by running the full `bin/ci`.

**Alternative:** skip with a printed notice when the base can't be found (friendlier to a clone without `origin/main`, weaker in CI if a checkout ever lost its history).

### 6. How the failure reads, and what it can't say (recommendation, OD5's companion)

The check can say **which** object, **where**, and that it has **no summary** (and whether the branch added or changed it). It can't say that a comment is stale, vague or what-not-why; the failure does not pretend to. The rule file says so too ("Keeping comments true"), pointing the checked part at the check and the rest at reviews.

## User Stories

All criteria are verified in RSpec against a throwaway git repository built in the example (the base, a branch with the change, the check run on it), except those marked "CI" or "read", which are recorded in `verification.md` from the pull request's run or by reading, per `.claude/rules/testing.md`.

### Story 1: A pull request that adds or changes public code without a comment fails

**As a** maintainer
**I want** `bin/ci checks` to fail when a branch adds or changes a judged object with no summary
**So that** new reusable code is documented in the pull request that adds it

**Acceptance criteria:**

- [ ] **AC-1.1** Given a branch that adds a public instance method with no comment to a file under `app/models/` When the check runs Then it exits non-zero and prints that file, the method's line and its name (`Widget#spin`)
- [ ] **AC-1.2** Given the same branch with a comment of one line of text above the method When the check runs Then it exits 0
- [ ] **AC-1.3** Given a branch that adds a public class method (`def self.build`, and a method inside `class << self`) with no comment When the check runs Then it fails and names each (`Widget.build`)
- [ ] **AC-1.4** Given a branch that adds a class with no comment, whose methods are all commented When the check runs Then it fails and names the class; with a comment above the class line it exits 0 (OD4)
- [ ] **AC-1.5** Given a branch that adds a module with no comment When the check runs Then it fails and names the module (as AC-1.4)
- [ ] **AC-1.6** Given a branch that edits a line inside the body of an existing public method that has no comment When the check runs Then it fails and names the method; and Given the method has a comment When the same edit is made Then it exits 0 (the comment's staleness isn't judged, decision 6)
- [ ] **AC-1.7** Given a branch that only deletes lines from inside an existing uncommented public method's body When the check runs Then it fails and names the method
- [ ] **AC-1.8** Given a branch that edits a line inside a method of an existing uncommented class and the method has a comment When the check runs Then it exits 0: the class is not changed (OD4)
- [ ] **AC-1.9** Given a method whose comment is tags only (`# @return [Integer]`) When the branch adds or changes it Then the check fails: there is no summary (OD2)
- [ ] **AC-1.10** Given a method marked `# @api private` with no other text When the branch adds it Then the check exits 0; and Given a private or protected method, a constant or an `attr_reader` with no comment When the branch adds them Then the check exits 0 (OD3)
- [ ] **AC-1.11** Given a branch that adds an uncommented public method to a file outside the scoped paths (a controller, a job, `db/`, `config/`, `script/`, `spec/models/`) When the check runs Then it exits 0, and Given the same method in each of `app/models/`, `app/models/concerns/`, `app/helpers/`, `app/controllers/concerns/`, `lib/` and `spec/support/` Then it fails (OD1)
- [ ] **AC-1.12** Given a new file that is not yet tracked or committed, with an uncommented public method When the check runs in the checkout Then it fails: the working tree is judged (decision 4)

### Story 2: Code the branch doesn't touch is never judged

**As a** contributor to a codebase at 54% coverage
**I want** the check to ignore everything I didn't change
**So that** a one-line fix never costs me an unrelated retrofit

**Acceptance criteria:**

- [ ] **AC-2.1** Given a checkout whose `HEAD` is `origin/main` with many uncommented public methods When the check runs Then it exits 0 and prints that it found no changed public code
- [ ] **AC-2.2** Given a branch that changes only a method with a comment, in a file that has uncommented public methods elsewhere When the check runs Then it exits 0 and names none of them
- [ ] **AC-2.3** Given a file renamed with no edit, containing uncommented public methods When the check runs Then it exits 0; and Given the renamed file with one uncommented method's line edited Then it fails naming that method only (decision 4)
- [ ] **AC-2.4** Given a branch that deletes a file or an uncommented method When the check runs Then it exits 0 for the deletion
- [ ] **AC-2.5** Given the branch merged `main` after `main` added an uncommented public method (as code merged before this check existed) When the check runs Then it exits 0 for that method and still fails for an uncommented method the branch added (decision 5)
- [ ] **AC-2.6** Given a change that only reformats lines inside an uncommented method When the check runs Then it fails naming the method (decision 4)

### Story 3: The failure is precise, and the check fails safe

**As a** contributor reading a failed run
**I want** each missing comment named with where to add it, and a clear message when the check can't see the branch
**So that** I fix the right thing, and a broken environment never passes quietly

**Acceptance criteria:**

- [ ] **AC-3.1** Given a branch with several objects missing a comment, across files When the check fails Then it prints one line per object (`path:line: Name has no comment`, saying whether the branch added or changed it), in path then line order, a count, and the path of `.claude/rules/code-documentation.md`
- [ ] **AC-3.2** Given a failed run When its output is read Then it states that comment quality and staleness aren't checked (decision 6)
- [ ] **AC-3.3** Given a checkout with no `origin/main` ref, or with no merge base with it When the check runs Then it exits non-zero with a message saying what is missing and to fetch `origin/main` (OD5)
- [ ] **AC-3.4** Given a changed scoped file that YARD can't parse When the check runs Then it fails naming the file, and doesn't skip it
- [ ] **AC-3.5** Given the check has run When `git status --ignored` is read Then it has written nothing: no `.yardoc/`, no file in the checkout
- [ ] **AC-3.6** Given a failed run When its output is read Then it never claims a comment is stale or poor, only that a summary is missing

### Story 4: It runs where `bin/ci checks` runs, and is documented

**As an** agent about to add a method
**I want** the rule, the check and the command written where I read them
**So that** I comment as I write and know what CI will say

**Acceptance criteria:**

- [ ] **AC-4.1** Given `config/ci.rb` When it is read Then the step is in the group `bin/ci checks` runs (not the RSpec group), after the YARD step, and `spec/config/ci_definition_spec.rb` says so
- [ ] **AC-4.2** Given a pull request that adds an uncommented public method to `app/models/` (a throwaway commit on this branch, reverted) When GitHub's `checks` job runs Then the job fails at this step, naming the object; with the commit reverted it passes. Recorded in `verification.md` (CI)
- [ ] **AC-4.3** Given the step When its run time is read from the branch's CI run and a local run Then it is at most 30 s
- [ ] **AC-4.4** Given this branch's own changes When the check runs on it Then it exits 0: the code it adds is commented as the rule asks
- [ ] **AC-4.5** Given the Dockerfile's build context and `.dockerignore` When they are read Then the check's files are left out of the image (they live under `script/`, which the build context leaves out), and `bin/image-smoke`'s absent-path list and `spec/image_publishing_spec.rb` name them if they sit outside a directory already listed
- [ ] **AC-4.6** Given `.claude/rules/code-documentation.md` When it is read Then it says which paths and objects the check judges, that `@api private` counts, that the check runs in `bin/ci checks`, and that quality and staleness stay with reviews (read)
- [ ] **AC-4.7** Given `CLAUDE.md`'s Commands list and its Claude Code Hooks section When they are read Then `bin/ci`'s description names the step, in lines of the existing style, and the Project Status paragraph isn't extended (read)
- [ ] **AC-4.8** Given `docs/architecture/release-and-deploy.md`, `docs/specs/README.md` and ADR 0027's consequence that "a later spec may add" a check When they are read Then the area doc states the step, the index has this spec's row and records that spec 054's Out of Scope "a rule that new code carries comments" is superseded (both directions), and ADR 0027 is not edited (read)

## Functional Requirements

### FR-1: The check

One command, run by `bin/ci checks`, that compares the working tree with the base (decision 5), finds the judged objects (decisions 1 and 3) the diff changed (decision 4) and exits non-zero when any has no summary (decision 2).

**Must:**
- Use YARD's parser for the objects, so its idea of a public method, class method and `class << self` is the one the site uses.
- Read the diff of the working tree against the base with renames followed, and treat an untracked scoped file as wholly added.
- Print every offender in one run (not stop at the first).
- Run without a database, a network, a running app or a container engine, and write nothing into the checkout (AC-3.5).

**Must not:**
- Judge an object the branch didn't change, or report a total or a percentage.
- Fail, or skip silently, when it can't see the base or can't parse a changed file (AC-3.3, AC-3.4).
- Load in the app: it is development tooling outside what the app autoloads and outside the image, as `script/yard/links.rb` is.

### FR-2: Failure output

**Must:** AC-3.1, AC-3.2 and AC-3.6: one line per offender, a count, the rule's path, the statement of what isn't checked.

**Must not:** call a comment stale, vague or wrong.

## Non-Functional Requirements

### Performance

- The step adds at most 30 s to `bin/ci checks` (AC-4.3); it parses only the changed scoped files (plus whatever YARD needs to resolve them), not the codebase.

### Security

- No new endpoint, route, secret or dependency (YARD is already a development gem). The image carries nothing new (AC-4.5).

### Reliability

- Deterministic for a given tree and base. It needs no network at run time (the base is a ref already fetched).
- A change in YARD's handling of an object kind (a new release) can change what the check sees; its specs run YARD over fixtures, so such a release fails them rather than the check passing wrongly, as spec 054's link extension's do.

### Compatibility

- No change to `.yardopts`, `bin/yard doc` or the site (Non-Goals); the check's file list is its own.
- Works in a Git worktree, in GitHub's `checks` job (full history) and on `main`.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A branch adds or changes a judged object with no summary | The step fails, listing each object with file and line (AC-1.1, AC-3.1) |
| No `origin/main`, or no merge base | The step fails with what to fetch (AC-3.3) |
| A changed scoped file YARD can't parse | The step fails naming the file (AC-3.4) |
| The branch changes nothing in scope | The step passes and says so (AC-2.1) |
| `main` was merged in and brought in uncommented code | Not judged (AC-2.5) |
| A change is only to a comment line | Not a method change; passes (nothing judged is changed) |
| A comment is present but stale or says nothing | Not caught; stays with reviews (decision 6, AC-1.6) |
| An author wants to exempt a one-caller helper | `@api private` with or without text (AC-1.10); no allowlist |

## Open Questions

Each is a decision for the maintainer, as the issue lists them. The recommendation is the text of the criteria; an alternative changes the criteria its tag names.

- **OD1 — Which files (decision 1).** Recommended: `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/`, `spec/support/`. Alternatives: models and lib only (AC-1.11 and the Glossary shrink); all of `app/`, `lib/` and `spec/support/` (AC-1.11 grows).
- **OD2 — What counts as commented (decision 2).** Recommended: a summary; tags alone don't count; `@param`/`@return` stay with review. Alternative: also require `@param` per parameter and `@return` where the method has parameters; AC-1.2 and AC-1.9 gain the tags and FR-1 reads parameters.
- **OD3 — Objects and `@api private` (decision 3).** Recommended: public classes, modules and methods; constants, attributes and non-public methods aren't judged; `@api private` counts as commented. Alternative: `@api private` objects need a summary (AC-1.10 changes), or constants are judged (new AC, a larger list).
- **OD4 — A class is changed only by its opening line (decision 4).** Recommended as written. Alternative: any change inside a class or module changes it (AC-1.4 and AC-1.8 change).
- **OD5 — An unseen base fails the check (decision 5).** Recommended: fail with a message. Alternative: skip with a notice (AC-3.3 changes).
- **OD6 — An ADR.** Recommended: **no new ADR**: ADR 0027 already says a later spec may add a gate and names the reason against a coverage gate, which this check keeps (it judges the diff, never the total), so the decision is recorded here and in `release-and-deploy.md`. Alternative: a short ADR 0028 that supersedes ADR 0027's "nothing measures or gates how much is documented" in part (ADR 0027 is then edited only in its Status, as the ADR index allows).

## Out of Scope (Future Considerations)

- Requiring `@param`/`@return` (OD2's alternative), or checking constants, controllers and jobs.
- A total-coverage report or gate.
- Detecting a stale comment (a comment unchanged while its method's body changed): it can't tell staleness from a harmless edit; a later spec could add a warning that doesn't fail.
- A checker for `@see file:` pages that don't exist (spec 054's Out of Scope).
- An exemption file, a baseline of today's undocumented code, or an override of the base by environment variable.

## Supersedes

- [Spec 054](../054-adopt-yard/spec.md) **Out of Scope, "A coverage gate, a list of undocumented objects in CI, or a rule that new code carries comments"**: the rule that new code carries comments is added here, as a check on what a branch changes; the coverage gate and the list of undocumented objects stay out. Spec 054 is not edited (`.claude/rules/documentation.md`); the supersession is recorded in `docs/specs/README.md`.
