# 0031: A dependency's licence is a decision: an allowed list, named exceptions, and a CI step that enforces both

## Status

Proposed (2026-11-13). Numbered 0031 because 0030 is spec 090's, on its own branch. Written with spec 091; the maintainer ruled its decisions 1 to 9 as recommended on 2026-11-13 and asked for this ADR (the coordinator's number 0031). It becomes Accepted with the pull request.

**Date:** 2026-11-13
**Feature:** 091-licence-check-in-ci

## Context

Collector is AGPL-3.0 as one codebase, and the maintainer intends a hosted service on the same code ([households and hosted service design](../superpowers/specs/2026-11-13-households-and-hosted-service-design.md), decision on one AGPL codebase). A dependency's licence is then something the maintainer wants to decide, not find out: a copyleft, field-of-use or source-available licence can arrive with a gem or a pinned JavaScript package. Until spec 091 nothing read which licence a dependency was under: spec 087's guard fails a pin or a font with no manifest entry and its page lists the licences, but a gem under the GPL-3.0 would pass `bin/ci`.

Measured on `main` at `71212946` (spec 091, Problem Statement): 142 gems in every Bundler group, 13 distinct sets of licences; all but two gems declare at least one of MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0 or Ruby. The two are development and test tools the application never loads, `bundler-audit` (GPL-3.0-or-later) and `brakeman` (Brakeman Public Use License). Three gems declare several licences and pass on one (`rdoc`, `diff-lcs`, `vcr`). The manifest side holds MIT, Apache-2.0, OFL-1.1 and ISC.

Facts about the tools: a gemspec's `licenses` is a list the author gives, and RubyGems gives it no either/or meaning (it is commonly written as a choice); the lockfile names gems, and `Bundler.load.specs` gives the installed ones with their declared `licenses`; a JavaScript package has no machine-readable metadata in CI (there is no `node_modules` and no network), so its licence is the `spdx` a person typed into `config/third_party_licences.yml` from the package.

## Options considered

**For what the check compares against:**

- **A. An allowed list of SPDX identifiers, with named exceptions (chosen).** Anything not on the list fails, so a new kind of licence is a decision by default. Costs: an occasional exception for a fine licence that is spelt unusually.
- **B. A deny list of copyleft families.** Fewer failures, but a licence the author didn't think of (a field-of-use licence such as Hippocratic-2.1, a source-available licence) passes silently. Not chosen.
- **C. No check; rely on review.** The state before this ADR. A copyleft gem enters as a transitive dependency of a bump nobody reads. Not chosen.

**For a component that declares several licences:**

- **A. It passes if any one is allowed (chosen).** The check reads the list as a choice, as it is commonly written, and the page shows the same identifiers. Costs: a gem whose list is not a choice passes on its allowed id, and the check trusts that id. `vcr` is today's case: it ships no licence file, and issue #408 calls it Hippocratic-2.1; its entry is pending the maintainer, with a named exception recommended (spec 091 decisions 2 and 3).
- **B. Every one must be allowed.** Stricter and unambiguous, but `diff-lcs`, `vcr` and `rdoc` would each need an exception for a licence nobody chose to use, which buries the exceptions that are real decisions. Not chosen.

**For which gems are judged:**

- **A. Every Bundler group (chosen).** Independent of what the image installs ([#408](https://github.com/plainprogrammer/Collector/issues/408)) and of the `Dockerfile`; a development tool under a restricted licence is a recorded exception.
- **B. Only what the image ships.** Smaller list of exceptions, but it depends on #408 and on a Dockerfile edit, and a contributor's tools escape. Not chosen.

## Decision

1. **`config/licence_policy.yml` records the allowed SPDX identifiers, each with a reason, and the exceptions.** Allowed: `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `ISC`, `Ruby` and `OFL-1.1`, and nothing else. Adding an identifier is a change to that file, which shows in review and is the maintainer's decision.
2. **A component with several identifiers passes if any one is allowed;** a component with none, or with a string that isn't exactly an allowed identifier (`MIT License`, an expression in one string), fails and names the string. Nothing is normalised.
3. **An exception names a gem, the set of licences it was reviewed under and the reason.** It goes stale, and fails the check, when the lockfile no longer names the gem, when the gem declares other licences, or when the gem is allowed without it. An exception may mark a gem whose list is not a choice (`all_required`), so every identifier must be allowed and the exception is what lets it through. Exceptions are for gems; a manifest entry under a disallowed licence is a change to the list or no dependency. Today: `bundler-audit` and `brakeman`.
4. **Every Bundler group is judged, and so is every entry of the third-party manifest** (JavaScript, OCR engine, fonts, icons) by its `spdx`, by the same rules. A run with some group left out judges what is installed, and a gem the lockfile names but the bundle lacks is neither judged nor stale; a manifest key the reader doesn't list is not judged (spec 091 decisions 3, 4 and 6). A manifest entry with a misspelt `spdx` has no exception and is corrected.
5. **The check is a step in `bin/ci checks`,** `bin/rails licences:check`, which judges the list spec 087's reader builds and also reports spec 087's guard, so a pull request that adds a gem or a pin under a licence off the list fails the checks job. The failure names the dependency, its licence and the policy file.

## Consequences

- **Good:** a dependency that declares only licences off the list can't enter unnoticed; the diff that allows one is one small file with a reason beside it. The page and the check read one list, so they can't disagree about what ships.
- **Good:** a release that changes an excepted gem's licence makes its exception stale, so the change is seen.
- **Cost:** a gem with an unusual spelling of an allowed licence needs an exception, or a correction of the list, until a better rule is worth its parser (spec 091 Out of Scope).
- **Limit:** the check trusts what is declared. A gem whose metadata says MIT and whose files say otherwise passes, and a manifest entry's `spdx` is only as good as the person who typed it from the package (its `source` says where); and a gem whose list of licences isn't a choice (`vcr`, above) passes on its allowed id unless it is excepted. The check makes no claim that a listed licence is compatible with the AGPL-3.0; the list is the maintainer's decision, recorded.
- **Limit:** a licence expressed as "all of A and B" can't be written in the metadata the check reads; it is judged by its listed identifiers, any one of which may pass.
- **Cost:** `bin/ci checks` gains a step that boots the application and reads about 400 KB of licence files (its time is recorded in spec 091's `verification.md`).
- **Follow-up:** [#408](https://github.com/plainprogrammer/Collector/issues/408) takes the two exceptions' gems out of the image; the exceptions stay, as development-tool exceptions.
