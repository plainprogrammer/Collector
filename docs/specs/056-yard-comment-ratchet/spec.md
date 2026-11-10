# Feature 056: New and Changed Public Code Carries a Comment (a YARD Ratchet in `bin/ci checks`)

**Status:** Approved by the coordinator under the maintainer's rulings of 2026-11-09 (OD1–OD6, all as recommended; the Opus re-review's non-blocking findings folded in)
**Version:** 1.2.3
**Created:** 2026-11-09
**Last Updated:** 2026-11-10
**Branch:** `056-yard-comment-ratchet`
**Issue:** [#264](https://github.com/plainprogrammer/Collector/issues/264), the follow-up to [#103](https://github.com/plainprogrammer/Collector/issues/103) (spec 054, [ADR 0027](../../adr/0027-yard-for-api-documentation.md)). The maintainer asked for this spec on 2026-11-09
**ADR:** open (OD6)
**Frozen:** the current rules are in [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (whole spec); see the [specs index](../README.md)
**Plan:** retired in `3aa1960297f638b76b13fcc71a6e2f0caed348bd`; read it with `git show 3aa1960297f638b76b13fcc71a6e2f0caed348bd^:docs/specs/056-yard-comment-ratchet/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-09 | Written from issue #264, `.claude/rules/code-documentation.md` (the guidance the check enforces), spec 054 and ADR 0027, and a spike of YARD 0.9.45's registry on the current code (Problem Statement). The issue's four questions are decisions 1–3 and 5 and 6 below; decisions 1–5 and the ADR question are recommendations for the maintainer to rule on (Open Questions OD1–OD6) |
| 1.1.0 | 2026-11-09 | From the spec review (Opus, read-only; REVISE, two blocking). **Detached HEAD:** GitHub's pull request checkout is detached, so the base is `git merge-base HEAD origin/main` whatever `HEAD` is, not `PushScope`'s rule (decision 5, AC-3.7, tag pushes). **Namespaces:** a class or module is judged only at its first definition and against a registry of every scoped file, so `module Collector` wrappers aren't judged and a comment above the outer wrapper doesn't count for the inner class (decision 4, AC-1.13, AC-1.14, AC-3.1). **Also:** a method's extent includes its own comment, deletions between methods judge neither (decision 4, AC-2.7, AC-2.8); what YARD can't see, and overrides (decision 3, AC-1.10, AC-1.15); FR-1's "Must not" sentence fixed; untracked means not ignored; criteria tagged by decision; OD6 quotes ADR 0027 |
| 1.2.3 | 2026-11-10 | PATCH, confirmed by the maintainer on 2026-11-10 (found by the implementation review, Opus Mode B; no ruling changes): the text now says what the approved plan's design does. A method is **new by qualified name** across the scoped files of the base, so a method moved between files of the same class with its text unchanged is not judged (decision 4; the plan listed it among its known limits); and a class or module marked `@api private` **covers the members** YARD scopes under it (decision 3, AC-1.10) |
| 1.2.2 | 2026-11-09 | From the plan review (Opus, read-only): a `(see Other#method)` comment **does** count once YARD resolves it to a method in the registry that has a summary (the check parses every scoped file at the head), and is empty only while the target is unresolved; a `# @!visibility private` directive makes YARD call a method private but is not an exemption, only the `private` keyword and `@api private` are; a class's report adds the namespace hint only for a class or module nested in another namespace (decisions 3 and 6, AC-1.10, AC-1.15, AC-3.1) |
| 1.2.1 | 2026-11-09 | Planning probed YARD 0.9.45 and corrected two statements, no ruling changes: a `Struct.new` or `Data.define` held in a constant **is** registered as a class (with its block's methods), so it is judged like any class, its comment above the constant's line (decision 3, AC-1.10); and a `(see Parent#method)` comment leaves the docstring empty, so it does not count as a summary (decision 3, AC-1.15) |
| 1.2.0 | 2026-11-09 | From the spec review round 2 (Opus, read-only; APPROVE WITH CHANGES, B1 and B2 resolved, nothing blocking), and the maintainer's rulings of 2026-11-09 (OD1–OD6 all as recommended). **"Changed" is a text comparison** of an object's extent with its base, so a deletion git places against a neighbour judges nobody (decision 4, AC-2.9); FR-1 reads the base side; **a shallow clone is refused** and the workflow keeps `fetch-depth: 0` (decision 5, AC-3.3, AC-4.9); the extent's glossary entry is for methods; the first-definition, unparseable-file, header-comment, tag and clean-checkout nits |

---

## Problem Statement

[ADR 0027](../../adr/0027-yard-for-api-documentation.md) kept documentation **coverage** out of `bin/ci`: at 53.7% of objects documented, a gate on the total "would need comments written for their own sake", and it said a later spec may add a check. `.claude/rules/code-documentation.md` asks that code **added or changed** carries a comment (the why, and for reusable code a summary, `@param`, `@return`), but nothing checks it; only a reviewer can notice that a new public method has none, and nobody is asked to look. The rule's own line is "apply these rules to code you add or change; don't retrofit untouched files just to comply", which is exactly the scope of a check that looks only at what a branch changed.

A spike of YARD 0.9.45's registry on the current code (nothing committed) measured what such a check would see:

- Public objects (classes, modules, methods, constants; attribute methods counted as methods) and how many have no comment text: `app/models` 1,088 and 454; `lib` 355 and 146; `spec/support` 243 and 110; `app/controllers` 158 and 98; `app/helpers` 69 and 26; `app/jobs` 15 and 8; `app/mailers` 1 and 1. A total gate would fail on about 840 objects today; a check on what a branch changes fails on none of them.
- Every object has a file and a line (`file`, `line`), and 3 have several locations: namespace wrappers (`Collector` in 22 files, `Collector::Backup` in 9, `Collector::Backup::Manifest` in 2). In this repository a file's header comment sits above its outer `module Collector` line, so YARD gives that comment to `Collector`, and the class the file defines (`Collector::PushScope`) is blank in the registry. The registry gives an object's first line but not its last, so the extent of a method must come from the source.
- YARD doesn't see `scope :x, -> {…}` declarations (none of `app/models`' 24 scopes is an object), `define_method`, `delegate`, or methods defined inside `RSpec.configure` and shared-context blocks; a `Struct.new` or `Data.define` assigned to a constant is registered as a class. Every `initialize` (59) has generated text ("A new instance of …"), so none is blank.
- A comment of tags only (`# @return [Integer]`) is "not blank" to YARD, and a method that overrides a documented one has an empty docstring of its own (nothing is inherited at the registry level). A method marked `# @api private` with no text is "blank". An `attr_reader` gets generated text ("Returns the value of attribute x."), so it is never blank. These are the places where "has a comment" needs a stated meaning (decisions 2 and 3).
- No object carries `@api private` today, so nothing needs exempting for that reason.

### Glossary

- **Scoped files:** the Ruby files the check judges (decision 1).
- **Judged object:** a public class, module or method (instance or class) in a scoped file (decision 3).
- **Changed object:** a judged object the branch added or changed (decision 4). The **extent** of a method is its own comment (the unbroken run of comment lines directly above it) through its `end`; a class or module is judged by its own comment and opening line only (decision 4).
- **Summary:** the comment's text before its first tag. A comment of tags alone has no summary.
- **The base:** the commit the branch is compared with (decision 5).

## Goals

- `bin/ci checks` fails when the branch adds or changes a judged object that has no summary, and names each such object with its file and line.
- The check looks only at what the branch changed: code the branch doesn't touch is never judged, so `main` passes whatever its coverage, and the codebase's documentation grows only as code is touched.
- It runs in the places `bin/ci checks` runs (the pre-push hook for documentation-only branches, `bin/ci`, GitHub's checks job) with no new configuration there. A local run judges the working tree, and CI judges the commits, so an untracked, not-ignored `.rb` file in scope can fail a local run (the pre-push hook's included) that CI wouldn't see.

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

### 1. Which files are judged (ruled, OD1)

**Recommendation:** Ruby files under `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/` and `spec/support/`: the "reusable code" the rule lists (concerns, helpers, `lib/`, plain Ruby objects under `app/models/`, and `spec/support/` helpers; the rule's "query methods and scopes" are judged only where they are `def` methods, decision 3). Controllers, jobs, mailers and channels are entry points that the framework calls and the routes and area docs describe; their actions would be commented for their own sake. `spec/support/` is not part of the YARD site (`.yardopts` has `app` and `lib`), so the check parses its own file list and the site is unchanged.

**Alternatives:** (a) the issue's minimum, `app/models/` and `lib/` only; (b) all of `app/`, `lib/` and `spec/support/`. The spike's counts above show what each would put in reach: (b) adds 158 + 15 + 1 public controller, job and mailer objects.

### 2. What counts as "has a comment" (ruled, OD2)

**Recommendation: a summary, any non-empty text before the first tag.** A comment of tags alone (`@return [Integer]`) is not a comment for this check, because the rule asks first for "a one-line summary saying what it gives the caller". `@param` and `@return` are **not** required: at 54% coverage most methods have no comment at all, a one-liner such as `def full_name = …` doesn't need them, and a check demanding them would produce comments for their own sake (ADR 0027). The rule's wording stays "reusable code gets `@param` and `@return`"; it is enforced by review.

**Alternative:** also require `@param` for each parameter and `@return` on methods with parameters, as the issue floats. The check can read the method's parameters from YARD; it would flag a method whose summary is fine because a tag is missing.

### 3. Which objects are judged, and `@api private` (ruled, OD3)

**Recommendation:** public classes, modules and methods (instance and class methods, including `class << self`). Not judged: private and protected methods, constants, and attribute methods (`attr_*`, which YARD documents on its own; the rule asks constants to carry their why, which a reviewer checks, and a check on every constant would flag lists of symbols). **An object marked `@api private` counts as commented**, with or without text: the rule tells the author to mark one-caller helpers that way, so the mark is the comment's answer to "is this meant for reuse", and requiring text as well would make the mark pointless. YARD passes a class's or module's `@api private` down to the members it scopes under it, so **a class or module marked `@api private` covers its members too**: they are not judged either (a whole internal class is marked once, not method by method).

The rule's other marks, `@private` and `@!visibility private`, are not exemptions: the author uses `@api private` (the directive makes YARD call a method private; the check still judges it, while a method that is private by the `private` keyword is exempt). **An override is judged like any method** (`to_param`, `==`, `call`): YARD inherits no text for it, so it needs its own summary (a `(see Other#method)` comment counts when YARD resolves it to a scoped method that has a summary, and is empty while the target is unresolved). **What YARD doesn't register isn't judged**, and the check doesn't pretend otherwise: `scope` declarations, `define_method`, `delegate`, and methods defined inside `RSpec.configure` or shared-context blocks (YARD registers none of them); a `Struct.new` or `Data.define` held in a constant **is** registered, as a class with its block's methods, and is judged like any class; `initialize` has generated text, so it is never blank (as the attributes).

**Alternative:** `@api private` objects are judged like any other (they need a summary too); or constants are judged.

### 4. What "changed" means (ruled, OD4)

A **method's extent** runs from its own comment (the unbroken run of comment lines directly above it) to its `end` (a one-line `def x = y` is one line). A method is changed when it is new (its qualified name, such as `Widget#spin` or `Widget.build`, is not defined in any scoped file of the base), or when the text of its extent differs from the text of its extent in the base (the same qualified name, wherever the base defines it). A method moved to another file of the same class, with its text unchanged, is neither new nor changed and is not judged. The comparison is of text, not of diff hunks, so it doesn't depend on where git places a deletion: deleting a whole method between two others changes neither of them, deleting a method's comment changes the method (an old method left with no summary fails), editing a comment that keeps its summary passes, and moving a method within a file changes nothing. A method that is a reformat of the base is a change.

A **class or module** is changed when it is new, or the text of its own comment or **opening** differs from the base's (`class Foo < Bar`, `module Foo`, the first line of `Foo = Struct.new(…) do`); a superclass change or a rename is an edit to the opening. Its members' text is not part of it. A branch that edits a method inside it does not change the class. **A class or module the base doesn't define is judged once**, however many files the branch opens it in: it passes if any of its definitions at the head has a summary, and is reported at YARD's `file:line` for it. Opening a namespace the base already defines (every `module Collector` wrapper in a new file of `lib/collector/`) adds nothing, and what counts as its comment is read from a registry of **every** scoped file at the head, not only the changed ones, so a namespace's comment written in another file is seen. The comment of a new file's header goes above the line of the class the file defines (`class PushScope` inside `module Collector`), or the namespaces above it are all the file defines and then it is theirs; a comment above only the outer `module Collector` line documents `Collector` and not the inner class.

**Recommendation** is that member edits don't pull in the enclosing class: touching a line of a 600-line model would otherwise demand a class comment as the price of any fix, which the rule's "don't retrofit untouched files just to comply" argues against. **Alternative:** any change inside a class or module changes it; the first edit to each old class then writes its comment, which ratchets faster and makes small fixes cost more.

The comparison is of the branch's working tree with the base, with renames followed (git's rename detection): a file moved with no edit changes nothing; an edited moved file is judged on the objects whose text changed. A file that is untracked and not ignored is entirely added. A deleted file or object is never judged. A change that only reformats a method (a RuboCop autocorrect inside it) is a change.

### 5. The base, and when it can't be found (ruled, OD5)

**Recommendation:** the base is `git merge-base HEAD origin/main`, **whatever `HEAD` is**: a branch, or the detached merge commit GitHub's `pull_request` checkout (`refs/pull/N/merge`) and a tag push check out. This is not `Collector::PushScope`'s rule, which refuses a detached `HEAD` for the pre-push hook (spec 035 decision 3); the check shares only its idea of the merge base. In GitHub's checks job (`fetch-depth: 0`) a pull request's merge base is `main`'s tip, so the check judges the pull request's own changes; on `main` itself (a push after a merge) and on a release tag at `main`'s tip the merge base is `HEAD`, nothing has changed, and the check passes. After a merge of `main` into the branch the merge base is the newest `main` commit in the branch's history, so what `main` brought in is not judged, only the branch's own changes. **`origin/main` and the history it needs** come from the workflow: the `checks` job checks out with `fetch-depth: 0`, which fetches every branch of the base repository (a pull request from a fork included) as `refs/remotes/origin/*` with the full history the merge base needs; the workflow must keep it. **A shallow repository is refused** (`git rev-parse --is-shallow-repository` is `true`): the check fails and names `fetch-depth: 0` and `git fetch --unshallow`, instead of judging against a merge base that history cut off. Locally the base is the `origin/main` the checkout last fetched: a branch rebased onto a local `main` that is ahead of `origin/main` is judged on `main`'s commits too, until `origin/main` is fetched. **When the base can't be found** (no `origin/main` ref, no merge base, a shallow repository) **the check fails** and says what to fetch, instead of passing: a check that silently passes where it can't see is the failure mode `PushScope`'s FR-4 avoids by running the full `bin/ci`.

**Alternative:** skip with a printed notice when the base can't be found (friendlier to a clone without `origin/main`, weaker in CI if a checkout ever lost its history).

### 6. How the failure reads, and what it can't say (the issue's fourth question; no open question)

The check can say **which** object, **where**, and that it has **no summary** (and whether the branch added or changed it); for a class or module nested in another namespace it adds that a comment above an enclosing namespace documents the namespace, not the class. It can't say that a comment is stale, vague or what-not-why; the failure does not pretend to. The rule file says so too ("Keeping comments true"), pointing the checked part at the check and the rest at reviews.

## User Stories

All criteria are verified in RSpec against a throwaway git repository built in the example (the base, a branch with the change, the check run on it), except those marked "CI" or "read", which are recorded in `verification.md` from the pull request's run or by reading, per `.claude/rules/testing.md`.

### Story 1: A pull request that adds or changes public code without a comment fails

**As a** maintainer
**I want** `bin/ci checks` to fail when a branch adds or changes a judged object with no summary
**So that** new reusable code is documented in the pull request that adds it

**Acceptance criteria:**

- [ ] **AC-1.1** Given a branch that adds a public instance method with no comment to a file under `app/models/` When the check runs Then it exits non-zero and prints that file, the method's line and its name (`Widget#spin`)
- [ ] **AC-1.2** (OD2) Given the same branch with a comment of one line of text above the method When the check runs Then it exits 0
- [ ] **AC-1.3** Given a branch that adds a public class method (`def self.build`, and a method inside `class << self`) with no comment When the check runs Then it fails and names each (`Widget.build`)
- [ ] **AC-1.4** (OD3, OD4) Given a branch that adds a class with no comment, whose methods are all commented When the check runs Then it fails and names the class; with a comment above the class line it exits 0 (OD4)
- [ ] **AC-1.5** (OD3) Given a branch that adds a module with no comment When the check runs Then it fails and names the module (as AC-1.4); and Given the branch edits a class's superclass or name on its opening line When the check runs Then the class is changed and fails without a comment (OD4)
- [ ] **AC-1.6** Given a branch that edits a line inside the body of an existing public method that has no comment When the check runs Then it fails and names the method; and Given the method has a comment When the same edit is made Then it exits 0 (the comment's staleness isn't judged, decision 6)
- [ ] **AC-1.7** (decision 4) Given a branch that only deletes lines from inside an existing uncommented public method's body When the check runs Then it fails and names the method
- [ ] **AC-1.8** (OD4) Given a branch that edits a line inside a method of an existing uncommented class and the method has a comment When the check runs Then it exits 0: the class is not changed (OD4)
- [ ] **AC-1.9** (OD2) Given a method whose comment is tags only (`# @return [Integer]`) When the branch adds or changes it Then the check fails: there is no summary (OD2)
- [ ] **AC-1.10** (OD3) Given a method marked `# @api private` with no other text When the branch adds it Then the check exits 0, while `# @private` or `# @!visibility private` alone fails; and Given a private or protected method, a constant, an `attr_reader`, an `initialize`, a `scope` declaration, a `define_method` or a method inside an `RSpec.configure` block with no comment When the branch adds them Then the check exits 0
- [ ] **AC-1.11** (OD1) Given a branch that adds an uncommented public method to a file outside the scoped paths (a controller, a job, `db/`, `config/`, `script/`, `spec/models/`) When the check runs Then it exits 0, and Given the same method in each of `app/models/`, `app/models/concerns/`, `app/helpers/`, `app/controllers/concerns/`, `lib/` and `spec/support/` Then it fails (OD1)
- [ ] **AC-1.12** Given a new file that is not yet tracked or committed, with an uncommented public method When the check runs in the checkout Then it fails: the working tree is judged (decision 4); and Given such a file that Git ignores Then the check doesn't see it

- [ ] **AC-1.13** (decision 4) Given a branch that adds `lib/collector/thing.rb` of the form `module Collector` / `class Thing` with its comment above `class Thing` When the check runs Then it exits 0 and `Collector` is not judged, though the file adds a `module Collector` line; and Given the file's only comment is above the `module Collector` line Then it fails naming `Collector::Thing`, not `Collector`
- [ ] **AC-1.14** (decision 4) Given a branch that edits a method of a nested class inside an outer class When the check runs Then the outer class is not changed and only the inner class's method is judged
- [ ] **AC-1.15** (OD3) Given a branch that adds an override (`def to_param` in a class whose parent's `to_param` is commented) with no comment of its own When the check runs Then it fails; with a one-line summary above it, or a `(see Parent#to_param)` to a commented method in scope, it exits 0

### Story 2: Code the branch doesn't touch is never judged

**As a** contributor to a codebase at 54% coverage
**I want** the check to ignore everything I didn't change
**So that** a one-line fix never costs me an unrelated retrofit

**Acceptance criteria:**

- [ ] **AC-2.1** Given a clean checkout whose `HEAD` is `origin/main` with many uncommented public methods When the check runs Then it exits 0 and prints that it found no changed public code
- [ ] **AC-2.2** Given a branch that changes only a method with a comment, in a file that has uncommented public methods elsewhere When the check runs Then it exits 0 and names none of them
- [ ] **AC-2.3** (decision 4) Given a file renamed with no edit, containing uncommented public methods When the check runs Then it exits 0; and Given the renamed file with one uncommented method's line edited Then it fails naming that method only (decision 4)
- [ ] **AC-2.4** Given a branch that deletes a file or an uncommented method When the check runs Then it exits 0 for the deletion; and Given the deleted method sat between two uncommented methods Then neither of them is judged (decision 4)
- [ ] **AC-2.5** Given the branch merged `main` after `main` added an uncommented public method (as code merged before this check existed) When the check runs Then it exits 0 for that method and still fails for an uncommented method the branch added (decision 5)
- [ ] **AC-2.6** (decision 4) Given a change that only reformats lines inside an uncommented method When the check runs Then it fails naming the method (decision 4)

- [ ] **AC-2.7** (decision 4) Given a branch that deletes the whole comment of an existing method that has no other summary When the check runs Then it fails naming the method; and Given it only rewords the comment's summary Then it exits 0
- [ ] **AC-2.8** (decision 4) Given a branch that adds a comment above an existing uncommented method and changes nothing else When the check runs Then it exits 0

- [ ] **AC-2.9** (decision 4) Given a branch that deletes a whole method whose lines git places against the previous method's `end` (adjacent methods with similar endings) When the check runs Then neither neighbouring method is judged; and Given a method moved within its file with no other change Then it isn't judged

### Story 3: The failure is precise, and the check fails safe

**As a** contributor reading a failed run
**I want** each missing comment named with where to add it, and a clear message when the check can't see the branch
**So that** I fix the right thing, and a broken environment never passes quietly

**Acceptance criteria:**

- [ ] **AC-3.1** Given a branch with several objects missing a comment, across files When the check fails Then it prints one line per object (`path:line: Name has no comment`, saying whether the branch added or changed it; a nested class's line adds that a comment above an enclosing namespace documents the namespace), in path then line order, a count, and the path of `.claude/rules/code-documentation.md`
- [ ] **AC-3.2** Given a failed run When its output is read Then it states that comment quality and staleness aren't checked (decision 6)
- [ ] **AC-3.3** (OD5) Given a checkout with no `origin/main` ref, or with no merge base with it, or a shallow clone even with `origin/main` present When the check runs Then it exits non-zero with a message saying what is missing, and to fetch `origin/main` or, for a shallow clone, `fetch-depth: 0` and `git fetch --unshallow`
- [ ] **AC-3.4** Given a changed scoped file that YARD can't parse When the check runs Then it fails naming the file, and doesn't skip it; and Given an unchanged scoped file YARD can't parse Then it is ignored (the site's build reports it)
- [ ] **AC-3.5** Given the check has run When `git status --ignored` is read Then it has written nothing: no `.yardoc/`, no file in the checkout
- [ ] **AC-3.6** Given a failed run When its output is read Then it never claims a comment is stale or poor, only that a summary is missing

- [ ] **AC-3.7** (decision 5) Given a detached `HEAD` that is a merge commit of the branch into `origin/main` (as GitHub's pull request checkout) When the check runs Then it judges the branch's changes and does not fail for the detached `HEAD`; and Given a detached `HEAD` at `origin/main`'s tip (a tag push) Then it exits 0 with no changed code, as does a tag on an older commit that is an ancestor of `origin/main`

### Story 4: It runs where `bin/ci checks` runs, and is documented

**As an** agent about to add a method
**I want** the rule, the check and the command written where I read them
**So that** I comment as I write and know what CI will say

**Acceptance criteria:**

- [ ] **AC-4.1** Given `config/ci.rb` When it is read Then the step is in the group `bin/ci checks` runs (not the RSpec group), after the YARD step, and `spec/config/ci_definition_spec.rb` says so
- [ ] **AC-4.2** Given a pull request that adds an uncommented public method to `app/models/` (a throwaway commit on this branch, reverted) When GitHub's `checks` job runs Then the job fails at this step, naming the object; with the commit reverted it passes. Recorded in `verification.md` (CI)
- [ ] **AC-4.3** (CI) Given the step When its run time is read from the branch's CI run and a local run Then it is at most 30 s
- [ ] **AC-4.4** Given this branch's own changes When the check runs on it Then it exits 0: the code it adds is commented as the rule asks
- [ ] **AC-4.5** Given the Dockerfile's build context and `.dockerignore` When they are read Then the check's files are not in the image: `.dockerignore` leaves them out, and `bin/image-smoke`'s absent-path list and `spec/image_publishing_spec.rb` name them unless a directory already listed holds them
- [ ] **AC-4.6** Given `.claude/rules/code-documentation.md` When it is read Then it says which paths and objects the check judges, that a file's header comment goes above the class the file defines, not above its `module Collector` wrapper, that `@api private` counts, that the check runs in `bin/ci checks`, and that quality and staleness stay with reviews (read)
- [ ] **AC-4.7** Given `CLAUDE.md`'s Commands list and its Claude Code Hooks section When they are read Then `bin/ci`'s description names the step, in lines of the existing style, and the Project Status paragraph isn't extended (read)
- [ ] **AC-4.8** (OD6) Given `docs/architecture/release-and-deploy.md`, `docs/specs/README.md` and ADR 0027's consequence that "a later spec may add" a check When they are read Then the area doc states the step, the index has this spec's row and records that spec 054's Out of Scope "a rule that new code carries comments" is superseded (both directions), and ADR 0027 is not edited (read)
- [ ] **AC-4.9** (decision 5) Given `.github/workflows/ci.yml` When it is read Then the `checks` job's checkout has `fetch-depth: 0`, and an RSpec example names this spec beside the one that already checks it (`spec/script/upgrade/files_spec.rb`) or in `spec/config/ci_definition_spec.rb`

## Functional Requirements

### FR-1: The check

One command, run by `bin/ci checks`, that compares the working tree with the base (decision 5), finds the judged objects (decisions 1 and 3) the diff changed (decision 4) and exits non-zero when any has no summary (decision 2).

**Must:**
- Use YARD's parser for the objects, over every scoped file at the head (so a namespace's comment in another file is seen), so its idea of a public method, class method and `class << self` is the one the site uses.
- Compare the working tree with the base with renames followed, and treat an untracked, not-ignored scoped file as wholly added.
- Read the base version of each changed scoped file, and the classes and modules the base defines across every scoped file (`git show <base>:<path>` into memory), so "new" and "changed" are answered by comparing text (decision 4).
- Print every offender in one run (not stop at the first).
- Run without a database, a network, a running app or a container engine, and write nothing into the checkout (AC-3.5).

**Must not:**
- Judge an object the branch didn't change, or report a total or a percentage.
- Pass, or skip silently, when it can't see the base or can't parse a changed file (AC-3.3, AC-3.4).
- Load in the app: it is development tooling outside what the app autoloads and outside the image, as `script/yard/links.rb` is.

### FR-2: Failure output

**Must:** AC-3.1, AC-3.2 and AC-3.6: one line per offender, a count, the rule's path, the statement of what isn't checked.

**Must not:** call a comment stale, vague or wrong.

## Non-Functional Requirements

### Performance

- The step adds at most 30 s to `bin/ci checks` (AC-4.3); it parses every scoped file at the head, and the changed files and namespaces' definitions at the base, in memory (a few seconds, as the site's build parses `app` and `lib`), and judges only the changed objects.

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
| A change is only to a comment line outside any judged object's extent (a comment inside a method body is part of the method) | Not judged; passes. A comment above an object is part of its extent: deleting it changes the object (AC-2.7) |
| A comment is present but stale or says nothing | Not caught; stays with reviews (decision 6, AC-1.6) |
| An author wants to exempt a one-caller helper | `@api private` with or without text (AC-1.10); no allowlist |

## Open Questions

Ruled by the maintainer on 2026-11-09: each recommendation stands, so the criteria stand as written. The alternatives are kept so a later change knows what was weighed, and the tags in the criteria say what an alternative would change.

- **OD1 — Which files (decision 1).** Recommended: `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/`, `spec/support/`. Alternatives: models and lib only (AC-1.11 and the Glossary shrink); all of `app/`, `lib/` and `spec/support/` (AC-1.11 grows).
- **OD2 — What counts as commented (decision 2).** Recommended: a summary; tags alone don't count; `@param`/`@return` stay with review. Alternative: also require `@param` per parameter and `@return` where the method has parameters; AC-1.2 and AC-1.9 gain the tags and FR-1 reads parameters.
- **OD3 — Objects and `@api private` (decision 3).** Recommended: public classes, modules and methods; constants, attributes and non-public methods aren't judged; `@api private` counts as commented. Alternative: `@api private` objects need a summary (AC-1.10 changes), or constants are judged (new AC, a larger list).
- **OD4 — A class is changed only by its opening line (decision 4).** Recommended as written. Alternative: any change inside a class or module changes it (AC-1.4 and AC-1.8 change).
- **OD5 — An unseen base fails the check (decision 5).** Recommended: fail with a message. Alternative: skip with a notice (AC-3.3 changes).
- **OD6 — An ADR.** Recommended: **no new ADR**: ADR 0027 already says a later spec may add a gate and names the reason against a coverage gate, which this check keeps (it judges the diff, never the total), so the decision is recorded here and in `release-and-deploy.md`. Alternative: a short ADR 0028 that supersedes ADR 0027's "nothing measures or gates how much is documented" in part (ADR 0027 is then edited only in its Status, as the ADR index allows). ADR 0027's decision 1 says "nothing measures or gates how much is documented" and its Options say of a coverage check "Not now; nothing here prevents a later spec": this check measures no total and gates only the diff, and the second line is the hook for it, so no ADR is needed to stand beside either (AC-4.8).

## Out of Scope (Future Considerations)

- Requiring `@param`/`@return` (OD2's alternative), or checking constants, controllers and jobs.
- A total-coverage report or gate.
- Detecting a stale comment (a comment unchanged while its method's body changed): it can't tell staleness from a harmless edit; a later spec could add a warning that doesn't fail.
- A checker for `@see file:` pages that don't exist (spec 054's Out of Scope).
- An exemption file, a baseline of today's undocumented code, or an override of the base by environment variable.

## Supersedes

- [Spec 054](../054-adopt-yard/spec.md) **Out of Scope, "A coverage gate, a list of undocumented objects in CI, or a rule that new code carries comments"**: the rule that new code carries comments is added here, as a check on what a branch changes; the coverage gate and the list of undocumented objects stay out. Spec 054 is not edited (`.claude/rules/documentation.md`); the supersession is recorded in `docs/specs/README.md`.
