# Verification: Feature 084, the Running Version, Its Commit and the Licence, Shown in the App

**Spec:** [spec.md](spec.md) (v0.4.0) · **Plan:** [plan.md](plan.md) · **Issue:** [#374](https://github.com/plainprogrammer/Collector/issues/374)

This file maps each acceptance criterion to the spec example, run or document check that proves it. A path is a spec file; a quoted name is an example's title. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`).

Short names used below:
- **facts:** `spec/lib/collector/build_facts_spec.rb`
- **line:** `spec/requests/licence_line_spec.rb`
- **footer:** `spec/requests/footer_spec.rb`
- **sys-footer:** `spec/system/footer_spec.rb`
- **publishing:** `spec/image_publishing_spec.rb`
- **core:** `spec/footer_core_spec.rb`

## Runs

- **Targeted runs while building:** each batch's files, red then green; the counts are in the commit history's batches.
  - Phase 1: facts, 16 examples.
  - Phase 2: line, footer, core, the visitor request and system specs, 103 examples; then `bin/rspec spec/requests spec/system/footer_spec.rb`, 1360 examples, 0 failures.
  - T2.2: 28 examples.
  - Phase 3: publishing and `spec/smoke_scripts_spec.rb`, 40 examples, then publishing with T3.2's two examples, 39 examples, 0 failures.
- **Broad targeted run** (2026-11-13, after every task): `bin/rspec spec/requests spec/lib spec/*_spec.rb spec/system/footer_spec.rb spec/system/visitor_catalog_spec.rb`: 1826 examples, 0 failures.
- **Full `bin/ci`:** run by the pre-push hook at the first push, with a slot: passed at `62679906` (the hook prints nothing on success; the suite has 4712 examples by `bin/rspec --dry-run`).
- **The pull request's CI run:** [run 43453666543](https://github.com/plainprogrammer/Collector/actions/runs/43453666543) of [#378](https://github.com/plainprogrammer/Collector/pull/378), green at `62679906`: checks, the four RSpec shards, `ci`, `Image (linux/amd64)` and `Image (linux/arm64)` passed, and `Publish manifest list` was skipped, as on every pull request. In each `Image` job, the `Build` step's log reads `build-args: COLLECTOR_VERSION=pr-378` and `--build-arg COLLECTOR_REVISION=ad088972c548cef6cd16d2230137564feaf0fab9`, GitHub's merge commit. Its `Smoke test` step prints `== the build facts (spec 084)` and then `OK: collector:smoke passed the smoke test`.

### Image proof (T3.3, local, Docker 29.5.2 on arm64 via colima)

Built at `e8f04ba2` with `docker build --build-arg COLLECTOR_VERSION=0.0.0-smoke --build-arg COLLECTOR_REVISION=<HEAD> --build-arg COLLECTOR_SOURCE_URL=https://github.com/plainprogrammer/Collector/tree/<HEAD> -t collector:084 .` (exit 0). Then `bin/image-smoke` ran four times:

| Run | Exit | Last line |
|---|---|---|
| `bin/image-smoke collector:084` (Homebrew bash 5.3) | 0 | `OK: collector:084 passed the smoke test`, after `== the build facts (spec 084)` |
| `… -e COLLECTOR_REVISION=` | 1 | `FAIL: the image reports no 40-character revision (got ''): build it with --build-arg COLLECTOR_VERSION=<version> --build-arg COLLECTOR_REVISION=<40-character SHA> --build-arg COLLECTOR_SOURCE_URL=<https address of the source> (README.md, Building from source)` |
| `… -e COLLECTOR_REVISION=b8ec874d` (a short SHA) | 1 | `FAIL: the image reports no 40-character revision (got 'b8ec874d'): build it with …` |
| `… -e COLLECTOR_VERSION=` | 1 | `FAIL: the image reports no version: build it with …` |

The run flags reach `docker run` and override the image's `ENV`, so one build serves all four runs.

The passing run was first attempted under macOS's `/bin/bash` 3.2, and the script stopped at line 25 with `run_flags[@]: unbound variable`. Bash 3.2 calls an empty array unbound under `set -u`, a defect that predates this branch, and CI's bash 5 never met it. The run above used `/opt/homebrew/bin/bash` 5.3. The coordinator ruled to fix the defect in this PR, and `550586df` expands the flags as `${run_flags[@]+"${run_flags[@]}"}`. Re-run with `/bin/bash` 3.2.57 against `collector:084`: no flags gives exit 0, `OK: collector:084 passed the smoke test`; `-e COLLECTOR_REVISION=` gives exit 1 with the build-arguments message, so a flag still reaches `docker run`.

### Mutation proofs

- **`REVISION_RULE` loosened to `/\A\h{7,40}\z/`:** facts and line ran 32 examples with 3 failures:
  - facts "drops a revision that isn't 40 hexadecimal characters (AC-2.8)"
  - facts "gives no revision, and raises nothing, when git is missing, fails or answers no SHA (AC-2.6)"
  - line "shows no SHA for a revision that isn't 40 characters (AC-2.8)"

  Restored.
- **`|| format('pr-{0}', …)` dropped from the workflow's version expression:** publishing ran 39 examples with 1 failure, "passes the same build facts to both builds, pr-N on a pull request (spec 084 AC-3.2, AC-3.6)". Restored.

## Acceptance criteria

### Story 1: The licence line is on every page, for everyone

| AC | Proved by |
|---|---|
| AC-1.1 | line "ends the footer of a collector's pages (AC-1.1, AC-1.4)" (collection, card page, scanner, More) and "ends the deck page and an admin page (AC-1.1)"; footer's `expect_the_footer` (every page it already visited, now three lines, the licence line last) |
| AC-1.2 | line "is on a visitor's sign-in and sign-up pages (AC-1.2)" (first-run sign-up, sign-in, open sign-up); footer's signed-out examples |
| AC-1.3 | line "is on the open catalog's pages for a visitor (AC-1.3)" (`:public_catalog`, search and a card page) |
| AC-1.4 | line "ends the footer of a collector's pages (AC-1.1, AC-1.4)" (the two links, their addresses, only `rel` and `href`, no `target`); line "keeps exactly its two links when the version names a link's words (AC-2.13)" |
| AC-1.5 | footer "holds only the licence line when no type supplies a notice (spec 084 AC-1.5, supersedes spec 018 AC-2.3)" (one footer, one line, `body class="c-shell c-shell--footed"`) |
| AC-1.6 | line "appears once on the sign-in form shown again with 422 and with 429 (AC-1.6)"; footer "is on a form shown again after a failed submission (AC-1.6)" (the lot form's 422) |
| AC-1.7 | footer "is left out of an answer that isn't a page (AC-1.8)" (spec 018's numbering): no `<footer>` in a `Turbo-Frame` answer, a Turbo Stream answer or the health check, so no licence line, since the line is only ever inside the footer |
| AC-1.8 | core "covers the layout, the footer's partial, the model that collects the notices and the build facts' reader" (the list adds `app/views/layouts/_notice_lines.html.erb`, `lib/collector/build_facts.rb`, `config/initializers/build_facts.rb`) and "never says MTG, Magic, Wizards, Scryfall or Fan Content" |

### Story 2: The version and commit are shown

| AC | Proved by |
|---|---|
| AC-2.1 | line "reads a release's facts and links the given address, signed out and in (AC-2.1)"; facts "takes a release's facts as given (AC-2.1)" and "reads each row of decision 2's table" |
| AC-2.2 | line "reads the edge version (AC-2.2)" |
| AC-2.3 | line "shows no parentheses when there is a version and no revision (AC-2.3)" |
| AC-2.4 | facts "knows nothing, and links upstream, when nothing is given outside development (AC-2.4)" and "is read at boot from nothing in the test environment (AC-2.4, decision 10)"; line "ends the footer of a collector's pages (AC-1.1, AC-1.4)" (the test environment's line and upstream link) |
| AC-2.5 | facts "reads development and HEAD from git in development (AC-2.5)" |
| AC-2.6 | facts "gives no revision, and raises nothing, when git is missing, fails or answers no SHA (AC-2.6)" |
| AC-2.7 | facts "drops a version that breaks the rule (AC-2.7)"; line "reads as no version for one that breaks the rule (AC-2.7)" |
| AC-2.8 | facts "drops a revision that isn't 40 hexadecimal characters (AC-2.8)"; line "shows no SHA for a revision that isn't 40 characters (AC-2.8)"; the first mutation proof |
| AC-2.9 | facts "links upstream for an address that isn't absolute https with a host (AC-2.9)"; line "links upstream, and renders no script address, for an unsafe source address (AC-2.9)" |
| AC-2.10 | facts "never asks git in test or production (AC-2.10)" (git counted, not raised, so a stray call is seen); line "reads the facts with no query (AC-2.10)". No outbound request: `lib/collector/build_facts.rb` makes none, and WebMock blocks any in the suite |
| AC-2.11 | facts "trims each fact and lowercases the revision (AC-2.11, AC-2.12)"; line "shows a version without its surrounding whitespace (AC-2.11)" |
| AC-2.12 | facts "trims each fact and lowercases the revision (AC-2.11, AC-2.12)"; line "shows the short SHA in lower case (AC-2.12)" |
| AC-2.13 | facts "puts its two links on the fixed words, whatever the version says (AC-1.4, AC-2.13)"; line "keeps exactly its two links when the version names a link's words (AC-2.13)" |
| AC-2.14 | facts "reads each row of decision 2's table"; line "names the SHA alone when the version is refused (AC-2.14)" |

Decision 6's "never raises on any value" is also proved by facts "never raises, on a byte that isn't UTF-8 or an address URI can't parse (decision 6)". Decision 10 is proved by facts "is replaced by the spec helper with raw values, cleaned as the image's would be (decision 10)" and "puts the boot reading back (the suite's after hook)".

### Story 3: The image carries its build facts

| AC | Proved by |
|---|---|
| AC-3.1 | publishing "takes the build facts last in the final stage, after every COPY (spec 084 AC-3.1)" |
| AC-3.2 | publishing "passes the same build facts to both builds, pr-N on a pull request (spec 084 AC-3.2, AC-3.6)" |
| AC-3.3 | The image proof's passing run; publishing "fails an image that reports no version or no full revision, from captured output (spec 084 decision 7)" (the script's text); [run 43453666543](https://github.com/plainprogrammer/Collector/actions/runs/43453666543) (both architectures' `Smoke test` steps passed the build facts check) |
| AC-3.4 | The image proof's three failing runs (no revision, a short revision, no version), each naming the three build arguments |
| AC-3.5 | [run 43453666543](https://github.com/plainprogrammer/Collector/actions/runs/43453666543): `bin/image-smoke` passed in both `Image` jobs with the version `pr-378` (Runs, above) |
| AC-3.6 | [run 43453666543](https://github.com/plainprogrammer/Collector/actions/runs/43453666543): both `Build` steps logged `COLLECTOR_VERSION=pr-378`, although `docker/metadata-action` gave no version. Also checked statically: publishing's AC-3.2/3.6 example and the second mutation proof. The spec says "there is no automated check of the workflow file"; the static example was added on top, and the run is still the evidence of the behaviour |

### Story 4: The footer still fits every screen

| AC | Proved by |
|---|---|
| AC-4.1 | sys-footer "stops above the phone's tab bar, inside the gutter, at 390px and 360px (AC-3.1, AC-3.2)" and "wraps inside the gutter on the sign-in page at 360px, where there is no tab bar (AC-3.2)". Both measure every line and now assert that the last line is the licence line. Screenshots `collection-390-*`, `sign-in-390-*` |
| AC-4.2 | sys-footer "gives the licence line's link the brand colour, contrast and focus ring, in the light theme (AC-4.2)" and "holds its contrast in the dark theme (AC-3.4)" (the licence line's link is `rgb(95, 183, 178)`); screenshots in both themes |
| AC-4.3 | sys-footer "is styled on the scanner page, under its policy (AC-4.1)" (the four links, the licence line's two among them, no inline style); footer "is on the scanner page, which sends the policy it always sent (AC-4.2)" (the policy unchanged) |
| AC-4.4 | Read: `docs/design-system/components/Footer.md` shows the third paragraph and says there is always a footer, the shell always `c-shell--footed` and the licence line last and the core's; none of decision 1's stale statements remain (`f6c05970`). `Sheet.md`, `VisitorHeader.md` and the README's lines 81 and 129 follow (decision 12) |

### Story 5: The documents agree

| AC | Proved by (read) |
|---|---|
| AC-5.1 | `README.md` (`b8ec874d`): Self-hosting says where the footer shows the version and commit; "Building from source" gives the three `--build-arg` flags with a fork's address; the Kamal own-registry paragraph has decision 9's `builder: args:` block with quoted ERB values; License mentions the footer's line |
| AC-5.2 | `docs/releasing.md` (`b8ec874d`): the build facts on every CI image, each trigger's version in the table, and step 6's footer check |
| AC-5.3 | `docs/architecture/release-and-deploy.md` (`b8ec874d`): decisions 3 to 7, 9 and 10 in "The image", a Named constants row and Sources. `docs/architecture/catalog-core.md` (`dff68597`): the licence line, its place, the always-present footer and the shared partial (decisions 1, 2, 11 and 12), and none of decision 1's stale statements |
| AC-5.4 | `CLAUDE.md` (`4d34b5d3`): Project Status and the "Footer and open catalog" bullet. `docs/specs/README.md`: spec 084's row and spec 018's "Superseded by" entry (`b7ed6183`, `e90c34e1`) |
| AC-5.5 | `docs/roadmap.md` (`a40d0e44`): #374's row and #376's row in the housekeeping lane; issue #376 was created by the coordinator |
| AC-5.6 | `compose.yaml` (`b8ec874d`): no `build:` section, and its `COLLECTOR_IMAGE` comment points to "Building from source". `Dockerfile` (`e8f04ba2`): its header points to the README instead of a bare `docker build` |

## Deviations and notes

- **T3.2 was written in the main session** (Opus), not by a Sonnet implementer, because the maintainer answers the `Dockerfile` and `ci.yml` permission prompts in the worker's terminal (ruling in `e8f04ba2`'s message). Every other task was written by a Sonnet 5.5 implementer, test first, one commit per task, and each commit names its model.
- **Implementers' fixes to the plan's code:**
  - facts' `read` helper takes `**given`: Ruby 3 binds a braceless string-keyed hash to keywords.
  - The visitor examples create a user first, so sign-in isn't first-run.
  - `licence` in footer is a `def`, because of `RSpec/MultipleMemoizedHelpers`.
  - The boot example also asserts the reading's class, since an unset `Rails.configuration.x` key answers nil to anything.
- **`release-and-deploy.md`'s `ci.yml:NNN` citations were already out of date on `main`** before this branch (for example "Digest artifact retention … `ci.yml:206`" when the line was 218). This branch's build-args move them a few lines further. Fixing them all is left to a separate change; the two new citations (`ci.yml:160-163`, `ci.yml:202-205`) are correct at `e8f04ba2`.
- **`bin/image-smoke` under macOS's bash 3.2** stopped on an empty `run_flags` array. This predated the branch; it is fixed in `550586df`, as the coordinator ruled.
- **Screenshots** (`1396a1b6`) use factory data with placeholder printings, built by a throwaway system spec with `build_facts(version: "0.3.0", revision: "a9f6de7c…")`, which was deleted before the commit.

## Implementation review

SPEC-ALIGNED (sdd-review Mode B, Opus 5.5, read-only, 2026-11-13, at `fd9705fe`)

The code matches spec 084 v0.4.0: every FR, decisions 1 to 12, and the exact strings of decision 2's table. Each claim in this file from AC-1.1 to AC-2.14 and AC-4.1 to AC-4.3 was checked against its example. The review had one major finding and seven minor ones.

1. **Major:** AC-3.5 and AC-3.6 wait for the pull request's CI run (and AC-3.3's two architectures with them). **Closed by [run 43453666543](https://github.com/plainprogrammer/Collector/actions/runs/43453666543)** (Runs, above).
2. **Minor:** AC-3.4's failing runs override a built image's facts with `-e` instead of building an image without them. **Accepted:** both routes leave the same environment for the script's `printenv`, which is what the check reads.
3. **Minor:** the `Dockerfile` comment and the area doc said that declaring the facts last means "a new commit rebuilds only this layer", which is false, since `COPY . .` rebuilds on every commit. **Fixed:** the area doc in `2db4fb20`, and the `Dockerfile` in `12ca0372` (the maintainer approved the text).
4. **Minor:** `VisitorHeader.md` still let `c-main` carry the clearance. **Fixed** in `2db4fb20`.
5. **Minor:** `Footer.md` listed three of the four readings. **Fixed** in `2db4fb20` (AC-2.14's reading added).
6. **Minor:** `catalog-core.md`'s phrase-search rule read as if it covered the licence line. **Fixed** in `2db4fb20` ("A type's line's …").
7. **Minor:** after a code reload in development, the stored facts are an instance of the old class. **Accepted and documented** in the initializer's comment (`8cb049c0`): the facts can't change while the process runs, and a reload of the reader takes effect at the next boot.
8. **Minor:** commit hygiene. T1.2 has a follow-up test commit (`9f38fcdc`, from the batch B fix), and `a40d0e44`'s subject has no `(#374)`. **Accepted:** history isn't rewritten. Every commit's trailer names the model that wrote it.

## Distillation

`distill-feature`, 2026-11-13. The area docs took the feature's rules during the build: `catalog-core.md` in T4.2 (`dff68597`, corrected in `2db4fb20`) and `release-and-deploy.md` in T4.3 (`b8ec874d`, corrected in `2db4fb20`). The distillation checked them against the spec and made these changes:

- **Distillation logs:** added one row to each doc (`4e8b3438`).
- **Index row:** spec 084 is Frozen by those two docs, its footer markup is the design system's `Footer`, and its Plan reads "retirement owed" (`4e8b3438`).
- **The spec:** its `**Frozen:**` line went in on its own (`492362a3`, spec 027 D4).

No area lacks a doc, no ADR is proposed, and `CLAUDE.md` restates no rule the feature changed. The plan is retired after the merge.
