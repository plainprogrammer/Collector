# Verification: Spec 056, New and Changed Public Code Carries a Comment (a YARD Ratchet in `bin/ci checks`)

Spec: [spec.md](spec.md) v1.2.3. Plan: [plan.md](plan.md). Issue [#264](https://github.com/plainprogrammer/Collector/issues/264).

Each row names the example that proves the criterion (by its description and the AC tag in it), the command and its recorded output, or says "read" with what was read. The examples are in `spec/script/yard/comment_ratchet_spec.rb` unless another file is named; each cited description was checked against the file. `bin/rspec spec/script/yard/comment_ratchet_spec.rb` on 2026-11-10 at HEAD `76dfc8f8`: **82 examples, 0 failures**. The suite checks no prose (`.claude/rules/testing.md`), so the documentation criteria are verified by reading, here.

## Story 1: a pull request that adds or changes public code without a comment fails

| AC | Proof |
|---|---|
| AC-1.1 | "fails for an added public method with no comment, naming its file, line and name (AC-1.1, AC-3.1)" |
| AC-1.2 | "passes once the method has a one-line comment (AC-1.2)" |
| AC-1.3 | "judges added class methods, including those inside class << self (AC-1.3)" |
| AC-1.4 | "judges an added class and an added module, and accepts a comment above the line that opens them (AC-1.4, AC-1.5)". A shebang, a `frozen_string_literal`, an encoding, an Emacs coding or a `warn_indent` comment, or a shebang with a magic comment, is not a summary: six examples "fails a new class whose only comment is #{what} (AC-1.4)" and six "passes a new class with a real summary under #{what} (AC-1.4)" (the twelve magic-comment examples). A class whose only comment is a `@!parse`, `@!method` or `@!attribute` directive has no summary and fails with the normal line, without running the directive: "fails a new class or module whose only comment is #{what}, naming it, with no exception (AC-3.1)" (four, one per directive), and a summary before a directive passes: "passes a new class whose summary comes before a @!parse directive (decision 2)" |
| AC-1.5 | The same example (a new module); "changes a class when its opening line is edited (AC-1.5)" (superclass or name edited) |
| AC-1.6 | "judges an uncommented method whose body the branch edits, and not one whose comment stays (AC-1.6)" |
| AC-1.7 | "judges a method the branch only removes lines from (AC-1.7)" |
| AC-1.8 | "doesn't change an uncommented class when only one of its methods is edited (AC-1.8)" |
| AC-1.9 | "counts a comment of tags alone, `@private` or `@!visibility private` as no comment (AC-1.9, AC-1.10)" |
| AC-1.10 | The example above (`@private` and `@!visibility private` fail); "doesn't judge `@api private` objects, non-public methods, constants, attributes, initialize or what YARD doesn't register (AC-1.10)" (private, protected, constant, `attr_reader`, `initialize`, `scope`, `define_method`, `delegate`, and a method inside an `RSpec.configure` block in `spec/support/`). Also "judges a Struct.new or Data.define held in a constant as a class (decision 3)". `@api private` on a class covers its members (spec v1.2.3, decision 3): "doesn't judge the members of a class marked `@api private`, and judges them without the tag (AC-1.10, decision 3)" and "covers the members of a class whose only comment is `@api private`, with no text (AC-1.10, decision 3)" |
| AC-1.11 | The table of examples "judges an uncommented public method in #{path} (AC-1.11)" and "ignores an uncommented public method in #{path} (AC-1.11)", one per path: the six scoped paths judged, the unscoped ones (controller, job, `db/`, `config/`, `script/`, `spec/models/`) ignored |
| AC-1.12 | "sees a new file that isn't tracked yet and never one that Git ignores (AC-1.12)"; "doesn't take a tracked symlink to a scoped file for a changed file (AC-1.12)" (added for the symlink case found in review) |
| AC-1.13 | "doesn't judge a namespace a new file reopens (AC-1.13)"; "doesn't count a comment above the outer wrapper for the class the file defines (AC-1.13)". Both start from a base whose own file opens `module Collector` with no comment (the `other` helper of the "namespaces" group), so a comment on the base's definition can't hide the namespace being judged |
| AC-1.14 | "judges only the inner class's method when a method of a nested class is edited (AC-1.14)" |
| AC-1.15 | "judges an override on its own; a summary, or a (see …) to a commented method, counts (AC-1.15)" |

## Story 2: code the branch doesn't touch is never judged

| AC | Proof |
|---|---|
| AC-2.1 | "passes, and says it found no changed code, when the branch changes nothing (AC-2.1)"; and the recorded run (a) below on this branch |
| AC-2.2 | "ignores the uncommented methods of a file whose commented method is the only one edited (AC-2.2)" |
| AC-2.3 | "passes a file renamed with no edit, and judges only the edited method of a renamed and edited one (AC-2.3)" |
| AC-2.4 | "never judges a deletion, of a method or of a file (AC-2.4)" for the deletion half. The "deleted method sat between two uncommented methods" half is the AC-2.9 example below, as plan.md Phase 5 says |
| AC-2.5 | "doesn't judge what main changed while the branch didn't merge it (AC-2.5)"; "judges only the branch's own code after a merge of main that brought uncommented code (AC-2.5)" |
| AC-2.6 | "judges a method the branch only reformats (AC-2.6)" |
| AC-2.7 | "counts deleting a method's comment as changing it, and rewording a comment that keeps its summary as nothing (AC-2.7)" |
| AC-2.8 | "passes a comment added above an existing uncommented method (AC-2.8)" |
| AC-2.9 | "judges neither neighbour of a deleted method, and not a method that only moved (AC-2.9)" (also carries AC-2.4's second half). A method is new by qualified name across the base's scoped files (spec v1.2.3, decision 4): "doesn't judge a method moved to another file of the same class with its text unchanged, and judges one edited on the way (decision 4)" |

## Story 3: the failure is precise, and the check fails safe

| AC | Proof |
|---|---|
| AC-3.1 | The four "fails a new class or module whose only comment is #{what}, naming it, with no exception (AC-3.1)" examples (a `@!parse` directive defining a class or a method, `@!method`, `@!attribute`: the exact offender line, no `Errno::ENOENT`); "doesn't crash on an unchanged file whose only comment is a @!parse directive when the branch changes another file (AC-3.1)"; "prints one line per object in path then line order, a count, the rule's path and what isn't checked (AC-3.1, AC-3.2, AC-3.6)"; "says, for a class inside a namespace, that a comment above the namespace documents the namespace and not the class (AC-3.1)" |
| AC-3.2 | The first example of AC-3.1 (it also asserts the statement that quality and staleness aren't checked) |
| AC-3.3 | "fails, saying to fetch origin/main, when there is none (AC-3.3)"; "fails when the branch shares no history with origin/main (AC-3.3)"; "fails on a shallow clone even when origin/main is there, naming fetch-depth 0 (AC-3.3)" |
| AC-3.4 | "fails for a changed file YARD can't parse, and ignores an unchanged one (AC-3.4)"; "fails for a changed file that Ripper accepts and YARD drops (an encoding error), naming the file (AC-3.4)"; "fails for an edited file YARD drops even when its base version was just as unreadable, though it adds a comment (AC-3.4)"; "doesn't fail a changed file that holds no class, module or method: an empty one, comments only, or constants only (AC-3.4)"; "ignores an unchanged file YARD drops, and judges the changed ones beside it (AC-3.4)" |
| AC-3.5 | "writes nothing into the checkout (AC-3.5)"; "leaves YARD's registry empty and its logger level as it was when Snapshot.build raises (AC-3.5)" |
| AC-3.6 | The first example of AC-3.1 (it asserts the output never says "stale" or "poor") |
| AC-3.7 | "judges the branch's changes from a detached merge commit, as GitHub's pull request checkout is (AC-3.7)"; "finds nothing changed on a tag at the tip of origin/main (AC-3.7, a guard)"; "finds nothing changed on a tag at an older commit of origin/main, whose later commits edited code (AC-3.7)" |

Also covered, not tied to one AC: "exits 1 and prints each offender when run as a command, and 0 when nothing is missing (FR-1)" (the CLI's exit status and output, in a throwaway repository); "raises Unseen from Git#export for a path the base doesn't have (decision 5)"; the three namespace examples for a class defined in two files (decision 4: "changes a class defined in two files when the only comment is deleted, though the other definition is unchanged", "passes a new class whose summary is in one of its two files, with the summary first / the summary last", "fails a new class defined in two files when neither definition has a summary, reporting it once").

## Story 4: it runs where `bin/ci checks` runs, and is documented

| AC | Proof |
|---|---|
| AC-4.1 | `spec/config/ci_definition_spec.rb`: "runs the comment ratchet in bin/ci checks, directly after the YARD step and not with the RSpec group (spec 056 AC-4.1)". `config/ci.rb` lines 30-31 are the YARD step and the ratchet step, in that order |
| AC-4.2 | Local half: recorded run (b) below, the step failed naming the object and passed with the probe reverted. CI half: **Not yet verified: recorded after the maintainer's scratch run** (ruling of 2026-11-10, route A: the maintainer pushes a throwaway failing commit to a scratch branch off this one with a pull request, by hand, the coordinator relaying; the pre-push gate is a Claude Code hook, so it doesn't stop their push). The plan's fallback if they decline: the pull request's own `checks` run shows the step passing on the merge ref, the failure on a detached merge commit is the AC-3.7 example, and run (b) below is the local half |
| AC-4.3 | Local: the step took 0.33 s on the branch (run (a), and inside `bin/ci checks`, run (b)); the failing run took 2.07 s; the worst case, all 165 scoped files added against an empty base, took 1.07 s and reported 569 offenders (Phase 3's throwaway measurement, not a spec example). A branch with no judged file differing parses nothing: "starts no parse when no judged file differs from the base (AC-4.3)". CI: **Not yet verified: recorded after the pull request's first CI run** (the `checks` job log's time for the step) |
| AC-4.4 | Recorded run (a) below: the check exits 0 on this branch |
| AC-4.5 | Read. `.dockerignore` line 62 is `/script`, and the check is `script/yard/comment_ratchet.rb`, so it is outside the build context; `bin/image-smoke` line 71 lists `script` among the paths that must be absent from the image, so a check there needs no path of its own. `spec/script/upgrade/files_spec.rb` "keeps bin/upgrade-smoke out of the image, and the image smoke test checks it (FR-8)" asserts `/script` is in `.dockerignore` |
| AC-4.6 | Read `.claude/rules/code-documentation.md`, "Keeping comments true". It says: `bin/ci checks` fails a branch that adds or changes a public class, module or method with no comment, naming the step and `script/yard/comment_ratchet.rb`; which paths are judged (`app/models/` with concerns, `app/helpers/`, `app/*/concerns/`, `lib/`, `spec/support/`); that a comment means summary text, tags alone, `@private` and `@!visibility private` don't count and `@api private` does (on a class or module it covers its members too), and a resolving `(see Other#method)` counts; what isn't judged; that it needs `fetch-depth: 0` and fails when it can't find the merge base; that a file's header comment goes above the class the file defines, not above `module Collector`; and, as a "don't", that staleness and what-not-why stay with reviews, with the "Code reviews" bullet amended to leave only the missing summary to the check |
| AC-4.7 | Read `CLAUDE.md`. The `bin/ci` Commands line now reads "setup, migration guard, RuboCop, YARD, the comment ratchet (spec 056: public code the branch adds or changes needs a summary; `.claude/rules/code-documentation.md`), Brakeman, …": it names the step and points to the rule without restating its scope. `git diff ffcb8085 HEAD -- CLAUDE.md` is that one line only, so the Project Status paragraph isn't extended. The Claude Code Hooks section (line 56) was read and needs no change: the pre-push hook already runs `bin/ci checks` for a documentation-only branch and the full `bin/ci` otherwise, and both include the step |
| AC-4.8 | Read `docs/architecture/release-and-deploy.md`: line 50 is the new bullet "The comment ratchet is a `bin/ci checks` step" (after which YARD step, what it judges, the merge base, the failure when the base is missing, `fetch-depth: 0`, the spec's decisions and ACs); line 51 lists it in the `bin/ci` order; line 124 names the two spec examples that check the configuration; line 276 has Spec 056 and #264 in Sources. Read `docs/specs/README.md`: row 056 exists (line 74) and the spec 054 row (line 72) records in its Supersedes column that "a rule that new code carries comments" is superseded by 056, so both directions exist (spec.md's "Supersedes" section is the third). `git diff ffcb8085 HEAD --stat -- docs/adr docs/specs/054-adopt-yard` is empty: ADR 0027 and spec 054 are not edited. ADR 0027's "Not now; nothing here prevents a later spec" (Options, line 26) is the hook the area doc cites |
| AC-4.9 | Read `.github/workflows/ci.yml` lines 23-26: the `checks` job's checkout step has `with: fetch-depth: 0`. `spec/script/upgrade/files_spec.rb` line 14, renamed to "fetches the full history and the tags in the checks job, which runs the guard and the comment ratchet's merge base (AC-8.5, AC-7.6 as superseded by spec 035; spec 056 AC-4.9)", asserts `fetch-depth` is `0` |

## Recorded local runs

All on 2026-11-10 at HEAD `82af8bb7`; the raw output of (b) is in `/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-yard-ratchet-gate/8a9d0f1f-66ad-49e7-a087-5542b19ad7be/scratchpad/ci-checks-fail.txt` and `ci-checks-pass.txt` (not committed).

- **(a)** `ruby script/yard/comment_ratchet.rb` on this branch printed "Found no added or changed public code in scope (compared with ffcb8085)." and exited 0, in about 0.3 s (AC-2.1, AC-4.4).
- **(b)** With `def probe = 1` (no comment) added to `lib/collector/dev_port.rb` in the working tree, uncommitted, `bin/ci checks` failed at the step "Docs: new and changed public code has a comment" after 2.07 s:
  `lib/collector/dev_port.rb:22: Collector::DevPort.probe has no comment (added)`, then the count line naming `.claude/rules/code-documentation.md` and the line that only a missing summary is checked. The group exited 1 ("Continuous Integration failed in 24.99s"; the steps after it still ran, as `bin/ci` does). After `git checkout -- lib/collector/dev_port.rb`, `bin/ci checks` exited 0: the step passed in 0.33 s, "Docs: YARD builds without warnings passed in 6.35s" with no `[warn]` line, and the whole group took 18.88 s (AC-4.2's local half, AC-4.3).
- **(c)** Worst case (Phase 3, a throwaway repository): all 165 scoped files added against an empty base took 1.07 s and reported 569 offenders (AC-4.3). The CLI's other behaviours observed there are the spec examples cited above.

## Phase 6 integration runs

| Run | Status |
|---|---|
| `ruby script/yard/comment_ratchet.rb; echo "exit=$?"` | Done: run (a) |
| An uncommented method added to `lib/collector/dev_port.rb`, `bin/ci checks`, then reverted | Done: run (b) |
| `bin/yard doc --no-cache` with no `[warn]` line | Passed inside `bin/ci checks` (run (b), the passing run): "Docs: YARD builds without warnings passed in 6.35s", no `[warn]` line. A separate `bin/yard doc --no-cache` is not run on its own |
| `bin/rspec spec/script/yard/comment_ratchet_spec.rb` | Done: 82 examples, 0 failures |
| Full `bin/ci` at the pushed SHA (every step, RSpec included; example count from `bin/rspec --dry-run`; the step's run time) | Not yet run |
| `bin/rspec --seed 1` and `bin/rspec --seed 42424` (the new spec file requires `yard` into the RSpec process; no example outside this feature changes its result) | Not yet run |
| The pull request's `checks` job log for the step (AC-4.2's CI half, AC-4.3's CI time) | Not yet verified: recorded after the pull request's first CI run / after the maintainer's scratch run (route A) |

## Known limits

Recorded as the plan listed them, not hidden:

- YARD attaches a comment that has one blank line before the `def`, which the extent doesn't include, so removing such a comment goes unjudged.
- A method made public with no edit to its text (moved above `private`) is judged, because it is no longer exempt in the base.
- An alias's extent is one line.
- A method that is private by the `private` keyword and also carries a `@!visibility private` comment is judged. (An earlier version of this line said a free-standing `# @!visibility private`, a blank line before the next `def`, exempts the methods after it; probed in a throwaway repository, both methods were judged.)
- A compact `class A::B` with no comment gets the namespace hint though no enclosing comment exists to blame.
- The check's own `git` calls use the developer's global Git configuration, so a global `core.excludesFile` can hide an untracked file from it. The spec's in-process examples likewise make their own Git calls with the developer's global configuration (only the `run_git` helper is isolated), so such a setting could hide an untracked file from AC-1.12's example.
- A renamed class or module is reported "(added)", not "(changed)": the base has no object by the new qualified name. It still fails when it has no summary (found in the Mode B round 2 review).
- A method that is private by the `private` keyword and also carries `# @!visibility private` is judged, as the line above says; the round 2 review confirmed it.
- `# -*- mode: ruby -*-` is treated as a magic comment, so a class whose only comment it is has no summary. That is stricter, never a wrong pass.
- `# rubocop:disable`, `# typed:`, `# vim:`, `# :nodoc:` and `# TODO` alone count as a summary, because YARD gives that text as the docstring (decision 2, "summary text before the first tag"). The check can't tell a tool's comment from prose.
- A `@!macro [new]` that expands into text counts as a summary, because YARD puts the expanded text in the object's docstring; and what a `@!parse`, `@!method` or `@!attribute` directive defines is registered by YARD at the line of the object the comment sits on, so an uncommented one is reported there beside the class (the examples under AC-3.1 assert the class's line is among the offenders).
- A file that Ripper accepts and that YARD drops with something other than the exception the after-parse callback catches is not known to be caught; no such case has been found.

What the plan listed and the implementation no longer has as a limit: a changed file YARD drops on an encoding error, or skips on `ArgumentError` or `NotImplementedError`, used to pass silently because only `Ripper` was consulted. The check now fails it, found through YARD's after-parse callback (commits `44e79f6a` test, `ae335019` fix; the examples under AC-3.4).

What the code review found and the implementation now does, which a reader of the check should know:

- A class's or module's `@api private` also covers the members YARD scopes under it (commit `0cc05bee`; `.claude/rules/code-documentation.md` says so; spec v1.2.3 now states it, decision 3).
- Symlinked files, tracked or untracked, are left out of the head's and the base's judged files (commits `d99becaa` test, `c4843e63` fix).
- A method moved between files of the same class is not judged, because a method is new by qualified name across the base's scoped files (spec v1.2.3, decision 4; the example under AC-2.9).
- `@api private` on a class or module covers its members (spec v1.2.3, decision 3; the examples under AC-1.10).
- A class whose only comment is a directive (`@!parse`, `@!method`, `@!attribute`) has no summary, and the check reads a comment's summary without running directives (commits `2ef5760a` test, `76dfc8f8` fix).

## Code review

An Opus code review of the implementation returned APPROVE WITH CHANGES, with three should-fix findings and some nits: a changed file YARD drops passed silently; a class defined in two files was judged by file order; and this `verification.md` was missing. They are folded in by commits `44e79f6a` through `0cc05bee` (the dropped file: `44e79f6a`, `ae335019`; the class in two files: `9a56e1dc`, `434a2f50`; the symlink nit: `d99becaa`, `c4843e63`; the `exempt?` documentation: `0cc05bee`), then `57c7285b` (the guards of `Git#export` and `Snapshot.build`), and by this file.

## Rulings

- **2026-11-10 (maintainer, via the coordinator):** the plan is approved, including the corrections of spec v1.2.2. AC-4.2 is verified by route A: the maintainer pushes a throwaway failing commit to a scratch branch off this one, with a pull request, by hand, and the coordinator relays the result; the fallback is recorded in the plan (Phase 4, the AC-4.2 item).
- **2026-11-10 (maintainer, via the coordinator):** spec v1.2.3 confirmed (PATCH): a method is new by qualified name across the base's scoped files, so a method moved between files of the same class is not judged; a class or module marked `@api private` covers the members YARD scopes under it. Both state what the approved plan's design and the code already did; no ruling changed.

## Implementation review

SPEC-ALIGNED

Round 1 (Opus, `sdd-review` Mode B, 2026-11-10) returned DRIFT DETECTED with four blockers: a magic comment or shebang counted as a class summary; the spec said "new in its file" while the code compares by qualified name; `@api private` on a class covering its members was not in the spec; and the AC-1.13 example started from a commented base.

Round 2 (Opus, same day) returned SPEC-ALIGNED with two should-fix items: the `@!parse` crash, fixed in commits `2ef5760a` (test) and `76dfc8f8` (fix), and this file being out of date, fixed here. The two blockers about the spec's wording (the qualified-name comparison and `@api private` on a namespace) were settled by spec v1.2.3, confirmed by the maintainer through the coordinator on 2026-11-10; the shebang and magic-comment finding and the AC-1.13 example were fixed in commits `3250b43b`, `73ae8282` and `a771ec11`.

AC-4.2's CI half and AC-4.3's CI time remain pending by ruling (route A, the scratch branch; and the pull request's `checks` job log), and are recorded in their rows above.
