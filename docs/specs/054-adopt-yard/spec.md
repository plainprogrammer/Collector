# Feature 054: Browsable API Documentation for the Ruby Code, with the Area Docs and ADRs Linked In (YARD)

**Status:** Approved by the coordinator under the maintainer's rulings of 2026-11-09 (OD1–OD3, all recommendations)
**Version:** 1.2.1
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `054-adopt-yard`
**Issue:** [#103](https://github.com/plainprogrammer/Collector/issues/103) (spec 027 slice B)
**ADR:** 0027 (YARD), written with this spec's plan. The issue and [spec 027](../027-architecture-area-docs/spec.md) say "ADR 0023"; that number is taken ([0023](../../adr/0023-locations-make-export-format-version-2.md)) and 0024–0026 were taken after it, so the YARD ADR takes the next free number, 0027, as spec 027 D9 and the [ADR index](../../adr/README.md) allow

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-09 | Written from issue #103, the starting shape in spec 027's Out of Scope ("Slice B: adopt YARD") and a measured spike of YARD 0.9.45 on the current code (Problem Statement). Decisions 1, 2 and 6 are recommendations for the maintainer to rule on (Open Questions) |
| 1.1.0 | 2026-11-09 | From the spec review (Fable, read-only; APPROVE WITH CHANGES, nothing blocking). **Extension and the app's boot:** a link-rewriting extension must never be loaded by the app, which eager-loads `lib/` (AC-3.7, decision 6). **ADR count:** 26 ADRs, and the ADR index is left out of the site because its name collides with the front page's (decision 1, AC-1.3). **Code to area doc:** the `@see` form is fixed and shown by one worked example (decision 5, AC-1.9). **New criteria:** fragments and the front page's links (AC-1.5), a dead link (AC-2.7), a stale cache (AC-2.8), globs (AC-1.3), the extension not autoloaded (AC-3.7). **Rewording:** the recommended rulings are written into the criteria, tagged OD1–OD3 where a different ruling changes them; one command everywhere (AC-2.1, FR-2); AC-1.2, AC-3.3 and AC-4.4 name their objects; the test files are named; the supersession claims less (Supersedes) |
| 1.1.1 | 2026-11-09 | Spec review round 2 (Fable, APPROVE WITH CHANGES, nothing blocking): a warning exits non-zero for everyone, the option is in `.yardopts` and the CI step adds only the no-cache option (FR-1, FR-2); OD1 and OD2 list every criterion they change and the criteria carry the tags; the Gemfile and CI-step examples are named as new; "26 ADRs" read as "26 today"; AC-3.7 and FR-3 reworded |
| 1.2.0 | 2026-11-09 | Approved. The maintainer ruled on OD1–OD3 (2026-11-09): all three recommendations stand, so the criteria stand as written and the alternatives are not taken. The decisions' headings say "ruled" |
| 1.2.1 | 2026-11-09 | Planning: the one `[NEEDS CLARIFICATION]` (Markdown processor and comment markup) is resolved by a spike: YARD's own renderer, `--markup markdown`, no extra gem; AC-3.5 and AC-4.2 lose the "if the plan needs one" wording; the comment that renders as a stray tag is fixed with the warnings (AC-2.1). No ruling changes |

---

## Problem Statement

A developer or an agent who wants to know what a Ruby class in `app/` or `lib/` is for, or which method to call, reads source files one at a time. The comments that exist (about 54% of the classes, modules, constants and methods carry one) are only reachable that way, and the current architecture, which [spec 027](../027-architecture-area-docs/spec.md) put into [area docs](../../architecture/README.md) and [ADRs](../../adr/README.md), is in Markdown files that sit apart from the classes they describe. Spec 027 left this as slice B: a generated, browsable site of the Ruby API with the area docs beside it, none of which is committed or shipped.

A spike on the current code (YARD 0.9.45, run outside the repository, nothing committed) measured the starting point:

- `app/` and `lib/` give 197 files, 61 modules, 210 classes, 838 methods, 53.7% documented; the run takes about 8 s.
- It gives **3 warnings**: `{name,collector}` in `app/models/scanner/measurement_run.rb:4` and `{id}` twice in `lib/collector/ghcr_cleanup.rb:107,120` are read as YARD links and don't resolve. Nothing else warns, so a no-warnings rule can start at zero.
- With the 7 area docs and the 26 ADRs as extra pages the site is 5.6 MB and the area docs' tables render.
- The relative links inside those pages do **not** resolve in the site: the area docs link each other as `tenancy-and-accounts.md`, ADRs as `../adr/0024-….md` and specs as `../specs/…`, but YARD names its pages `file.<name>.html`. Of the 389 relative links in the area docs and ADRs, 179 (46%) point at documents that aren't pages of the site (specs, `docs/releasing.md`, `docs/design-system/`, source files); none is dead on disk. Spec 027's NFR keeps the area docs plain Markdown with relative links so they read well on GitHub, so the links must be made to work at generation, not in the files (decision 6).
- A comment can point at an area doc: `@see file:catalog-operations.md` renders a link to that page; the same tag wrapped in braces warns ("should not be wrapped in {}"); a tag naming a page that doesn't exist renders a dead link with **no** warning (decision 5).

### Glossary

- **The site**: the HTML YARD generates into `doc/`.
- **Included documents**: the pages added to the site besides the API reference: the 7 area docs (including `docs/architecture/README.md`, the front page) and the numbered ADRs (26 before this feature's ADR 0027).
- **Warning**: a line YARD prints beginning `[warn]`, such as an unresolved link, an unknown tag or a malformed tag.

## Goals

- One command generates the site from `app/` and `lib/` with the included documents as pages, and the area map is its front page.
- A comment that makes YARD warn fails CI; the code on `main` today builds with no warnings.
- Nothing YARD generates (`doc/`, `.yardoc/`) can be committed, and neither it nor anything that only builds it is in the published image; `bin/image-smoke` fails an image that holds any of it.

## Non-Goals

- Documentation **coverage** (a minimum percentage, or `yard stats --list-undoc` as a gate). At 53.7% most of the code is undocumented; a gate would need comments written for their own sake. A later spec may add one.
- Writing or rewriting comments beyond the three that warn and the one worked-example `@see` (AC-1.9). Existing "spec NNN AC-x" comments stay as they are (spec 027's starting shape).
- Publishing or hosting the site (GitHub Pages, the image, a container). It is generated locally and in CI's check only.
- Rendering `docs/specs/`, `docs/lessons/`, `docs/design-system/`, `docs/adr/README.md`, the repository's `README.md` or any other document as a page (decisions 1 and 6 say how links to them behave).
- Changing the area docs' shape or their relative links (spec 027 NFR "Compatibility"), or the `Dockerfile` or its build.
- Type annotations (`@param [Type]`) on existing methods, or a type checker.
- Catching a comment's `@see file:…` that names a page that doesn't exist: YARD doesn't warn for it (Problem Statement), and a check of its own is out of scope.

## Users and Context

**Primary users:** the maintainer and agents (Claude Code sessions) who read, change and review the Ruby code.
**Secondary users:** contributors reading the repository.
**Usage context:** before changing a class, a reader opens the site and finds the class's comment, its methods, and the area doc and ADRs that explain the subsystem; when a comment is added or edited, the contributor runs the command or sees CI's check.
**User mental model:** "the API docs" are generated from the code's comments and never stored; the architecture is in the area docs and ADRs; the site puts the two side by side, and a comment's `@see` takes a reader from a class to its area doc.

## Decisions

### 1. The ADRs are included pages (ruled, OD1)

**Ruling (maintainer, 2026-11-09), the recommendation: include the numbered ADRs (`docs/adr/0*.md`; 26 today), not the ADR index (`docs/adr/README.md`).** The area docs cite ADRs on almost every page (122 of their 389 relative links target an ADR), and a reader following such a citation inside the site should land on the ADR. The cost measured in the spike is 26 more pages and under 1 MB. The ADR index is left out because its file name, `README`, would give it the same page name as the front page (`docs/architecture/README.md`); a link to it follows decision 6 like any other link to a document outside the site. A new ADR is picked up by the pattern with no change to the configuration. **Alternative:** area docs only, with ADR links pointing at GitHub (decision 6); a smaller site, but the reason for each choice is a click further from the code that follows it.

### 2. Warnings are checked by a `bin/ci` step (ruled, OD2)

**Ruling (maintainer, 2026-11-09), the recommendation: a step in `bin/ci checks`**, after the Ruby style step, running `bin/yard doc` with the options that make it fail on a warning and ignore any cache, and writing nothing into the checkout that isn't ignored. It adds about 8 s to `checks` (the spike's time, on the maintainer's machine) and runs wherever `bin/ci checks` runs: the pre-push hook for documentation-only branches (where a broken link in an area doc would otherwise pass unseen), `bin/ci`, and GitHub's checks job. **Alternative:** a command only; a warning then goes unseen until someone generates the site, and the count rises from zero.

### 3. Coverage is not checked, and private and protected methods stay hidden

YARD's defaults stand: undocumented objects appear (as undocumented), private and protected methods are hidden. No coverage number is recorded or gated (Non-Goals).

### 4. The front page is the area map

The site's front page is `docs/architecture/README.md` (the map of the areas), not the repository's `README.md`, which describes installing and running the app and has no place in an API reference. YARD would otherwise take the repository `README.md` as the front page when none is named.

### 5. Comment convention

Existing comments naming a spec and criterion ("spec 015 AC-2.16") are kept. A comment written or edited after this spec that points at an area doc or an ADR writes it as an `@see` tag in the form `@see file:<file name>.md` (for example `@see file:release-and-deploy.md`, `@see file:0024-backup-with-vacuum-into.md`), not wrapped in braces, so the site renders a link to that page and lists it apart from the prose. A reference to a spec (which isn't a page of the site) stays in the prose, as it is today. This spec adds one such tag to one class whose subsystem has an area doc, as the worked example (AC-1.9). The convention is written where agents read conventions and is not checked tag by tag (a check of every tag is the coverage kind of gate, Non-Goals).

### 6. Links in the included documents work in the site (ruled, OD3)

A relative link from an included document to another included document (area doc to area doc, area doc to ADR, ADR to ADR), with its fragment, opens that page in the site. **Ruling (maintainer, 2026-11-09), the recommendation:** every other relative link in an included document (a spec, `docs/releasing.md`, `docs/design-system/`, the ADR index, a source file) becomes a link to that file on GitHub's `main` branch in the site, so no link in the site is dead; the target's existence is checked on disk, so a link to a file added on the branch and not yet on `main` is accepted. The files keep their relative links (spec 027 NFR) and nothing is rewritten on disk: the rewriting is part of generation, in a small YARD extension loaded by `.yardopts`. The extension is a development tool: the app never loads it and never requires `yard` (AC-3.7), and it is kept out of the image (AC-3.2). **Alternative:** rewrite only the included-to-included links and leave the rest as written, dead in the site and live on GitHub (46% of the links); the code is then smaller, and AC-1.6 and AC-2.7 change as their tags say. The recommendation's cost is that extension and its unit specs.

## User Stories

All criteria that name a command are verified by running it and recording its output in `verification.md`; the criteria about documents are verified by reading, per `.claude/rules/testing.md`. Criteria about the repository's configuration files are checked in RSpec: `.dockerignore` and `bin/image-smoke` in `spec/image_publishing_spec.rb`, where such examples are; `.gitignore` in `spec/project_config_spec.rb` (it has the ignore helper); the Gemfile's group for `yard` and the CI step are new examples, in a spec file the plan names (`spec/config/ci_definition_spec.rb` for the step); the extension has unit specs. A criterion tagged OD1, OD2 or OD3 changes if the maintainer rules the alternative of that decision.

### Story 1: A reader browses the Ruby API with the architecture beside it

**As a** developer or agent changing the Ruby code
**I want** one command to generate a browsable site of the classes with the area docs and ADRs as pages
**So that** I find what a class is for, and the subsystem it belongs to, without reading source files one at a time

**Acceptance criteria:**

- [ ] **AC-1.1** Given a checkout with the development gems installed When `bin/yard doc` runs Then it exits 0, prints no `[warn]` line, and writes `doc/index.html`
- [ ] **AC-1.2** Given the site When its class list is read Then it has a page for each of `Lot`, `Account`, `Collector::Backup`, `MTG::Art::Operation` and `Catalog::Entry`, its object counts equal those `yard stats` reports for `app` and `lib`, and it has no page for a class that exists only in `spec/`, `config/`, `db/`, `script/` or `vendor/`
- [ ] **AC-1.3** Given the site When its file list is read Then it has a page for each of the 7 area docs and each numbered ADR (`docs/adr/0*.md`) (OD1), with their headings, tables and code blocks rendered as HTML, and none for `docs/adr/README.md`; and Given a new `docs/architecture/<name>.md` or `docs/adr/0NNN-<slug>.md` When the site is generated again with no other change Then it has a page for it
- [ ] **AC-1.4** Given the site When its front page is opened Then it shows the area map (`docs/architecture/README.md`), not the repository's `README.md`
- [ ] **AC-1.5** Given an included document (the front page, an area doc or an ADR) When a link in it to another included document is followed in the site, with or without a `#fragment` (for example `../adr/0024-backup-with-vacuum-into.md#consequences`) Then it opens that page, at that fragment (OD1: with area docs only, the example and "an ADR" go)
- [ ] **AC-1.6** Given an included document When a link in it to a document that isn't a page of the site (a spec, `docs/releasing.md`, `docs/adr/README.md`) is followed in the site Then it opens that file on GitHub's `main` branch (OD3; under OD1's alternative the ADRs join the documents that open there); an absolute URL and an in-page `#anchor` are unchanged
- [ ] **AC-1.7** Given the area docs and ADRs on disk When the site has been generated Then `git status` shows no change to any of them
- [ ] **AC-1.8** Given a second run When `bin/yard doc` runs again with no change Then it exits 0 with no `[warn]` line and the same pages
- [ ] **AC-1.9** Given the one class whose comment carries the worked-example `@see file:<area doc>.md` (decision 5) When the site is generated Then its page lists that tag as a link to the area doc's page, and the run prints no `[warn]` line

### Story 2: A comment that warns is caught before it merges

**As a** maintainer
**I want** CI to fail when a comment makes YARD warn
**So that** the documentation stays buildable and the warning count stays at zero

**Acceptance criteria:**

- [ ] **AC-2.1** Given the code at the branch's head When `bin/yard doc` runs Then it exits 0 with no `[warn]` line: the three comments that warn today (`app/models/scanner/measurement_run.rb:4`, `lib/collector/ghcr_cleanup.rb:107` and `:120`) no longer do, and their text still says what it said
- [ ] **AC-2.2** Given a comment with an unresolved link (for example `{nothing_here}`) or a malformed tag (for example a `@param` with no name) in `app/` or `lib/` When `bin/ci checks` runs Then the documentation step fails, names the file and line YARD printed, and `bin/ci` exits non-zero; with the comment reverted it passes (OD2). The run is recorded in `verification.md`
- [ ] **AC-2.3** Given `config/ci.rb` When it is read Then the documentation step is in the group that `bin/ci checks` runs and not in the RSpec group (OD2), and `spec/config/ci_definition_spec.rb` says so
- [ ] **AC-2.4** Given `bin/yard doc` or the step has run in a checkout When `git status --ignored` is read Then everything it wrote is in an ignored path (`doc/`, `.yardoc/` or `tmp/`) and nothing is tracked or untracked-and-unignored
- [ ] **AC-2.5** Given the step When its run time is read from the branch's CI run Then it is at most 30 s (OD2)
- [ ] **AC-2.6** Given `bin/yard doc` (or the step) fails on a bad comment When its output is read Then it contains YARD's warning lines (file, line and text), not only an exit status
- [ ] **AC-2.7** Given an included document with a relative link to a file that doesn't exist on disk When `bin/yard doc` runs Then it prints a warning naming the document and the link and exits non-zero, and `bin/ci checks` fails (OD3; the `bin/ci checks` clause is OD2)
- [ ] **AC-2.8** Given a `.yardoc/` left by an earlier clean run When a comment is then made to warn and `bin/ci checks` runs Then the step still fails: it never reads the cache (OD2)

### Story 3: Nothing generated is committed or shipped

**As a** maintainer of a public container image
**I want** the generated site and everything that only builds it kept out of Git and out of the image
**So that** the repository stays source-only and the image carries only what it runs (spec 012, ADR 0008)

**Acceptance criteria:**

- [ ] **AC-3.1** Given a generated `doc/` and `.yardoc/` When `git status` is read Then neither shows (both are in `.gitignore`)
- [ ] **AC-3.2** Given `.dockerignore` When it is read Then it excludes `/doc`, `/.yardoc`, `/.yardopts`, every binstub this feature adds (`bin/yard`, and `bin/yardoc` and `bin/yri` if the binstub command makes them) and the extension's file(s), each with a comment in the file's style saying why
- [ ] **AC-3.3** Given `bin/image-smoke` When its list of paths that must be absent from the image is read Then it names `doc`, `.yardoc`, `.yardopts`, each binstub of AC-3.2 and the extension's file(s), and `spec/image_publishing_spec.rb` checks that the rules and the list agree, as it does for the existing ones; an image that holds any of them fails the smoke
- [ ] **AC-3.4** Given the Gemfile and the `Dockerfile` When they are read Then `yard` is in the `:development` group only (never `:development, :test`) and the `Dockerfile`'s `BUNDLE_WITHOUT="development"` leaves it out of the image's bundle; the specs of the extension `require "yard"` themselves, which the full bundle of a checkout and of CI allows
- [ ] **AC-3.5** Given the Gemfile and `Gemfile.lock` When they are read Then `yard` is added by editing the Gemfile and running `bundle install`, with `require: false`, and `bin/bundler-audit` passes
- [ ] **AC-3.6** Given an image built from the branch When `bin/image-smoke` runs Then it passes. Checked in CI's image job; locally only if a container engine is at hand
- [ ] **AC-3.7** Given the extension's file(s) When the app eager-loads (`bin/rails zeitwerk:check`, and the suite with `CI=true`) Then the app boots and eager-loads without loading them or requiring `yard`: they are outside what the app autoloads or are in `config/application.rb`'s ignore list, as `lib/collector/ci_groups.rb` is

### Story 4: The documentation records and explains it

**As an** agent about to touch the Ruby comments or the image's contents
**I want** the commands, the rule and the decision written where I read them
**So that** I run the right command and don't re-decide it

**Acceptance criteria:**

- [ ] **AC-4.1** Given `CLAUDE.md`'s Commands list When it is read Then it names `bin/yard doc`, what it writes (`doc/`), and that `bin/ci checks` fails on a warning, in lines of the existing style; its description of `bin/ci`'s steps lists the documentation step; and the Project Status paragraph is not extended
- [ ] **AC-4.2** Given `docs/adr/0027-yard-for-api-documentation.md` When it is read Then it has the ADR sections in their order, Status `Accepted`, the choice of YARD (against RDoc and no generated docs), the Markdown rendering (YARD's own, no extra gem), decisions 1, 2 and 6 as ruled, and the consequences; `docs/adr/README.md` has its index row and its "Expected" paragraph no longer lists YARD
- [ ] **AC-4.3** Given `docs/architecture/release-and-deploy.md` When it is read Then its image statements ("The image carries only what it runs", "`bin/image-smoke` fails an image that…") list the paths of AC-3.2 and AC-3.3, with this spec as their source, its statement of which configuration files the suite checks names what the new RSpec examples check, and its Sources and Distillation log are updated per the documentation rules
- [ ] **AC-4.4** Given `.claude/rules/conventions.md` When it is read Then it states the comment convention of decision 5 (OD1: `@see file:` for an area doc only) and that a comment with an unresolved `{…}` fails `bin/ci checks` (OD2)
- [ ] **AC-4.5** Given `docs/architecture/README.md` When it is read Then it says the area docs are also pages of the generated site and how to build it, and its links are still plain relative ones (spec 027 NFR)
- [ ] **AC-4.6** Given `docs/specs/README.md` and `docs/roadmap.md` When they are read Then the index has this spec's row (Draft until approved, then per the documentation rules); spec 027's row lists "Out of Scope, Slice B (the starting shape, decided here), and the expected ADR number 0023 (0027): 054" under Superseded by, and this spec's row says the same under Supersedes; and the roadmap's #103 line names this spec and ADR 0027
- [ ] **AC-4.7** Given the supersession of AC-4.6 When this spec is read Then it records it ("Supersedes", below), and spec 027's file is not edited

## Functional Requirements

### FR-1: The command

`bin/yard` is a binstub of the `yard` gem; `bin/yard doc` generates the site.

**Must:**
- Read its options from `.yardopts` at the repository root (so a plain `yard doc` and an editor's tool behave the same): sources `app` and `lib`; the included documents as patterns (decision 1); the front page (decision 4); the output directory `doc/`; the link extension (decision 6); and that a warning makes the run exit non-zero.
- Treat `.yardopts` as the one definition of what goes in the site.

**Must not:**
- Require a running app, a database, a network or a container engine.
- Write anywhere that isn't ignored by Git (AC-2.4).

### FR-2: The warnings check

A step in `config/ci.rb` (decision 2) runs `bin/yard doc`. A warning makes the command exit non-zero for everyone, a developer included (the option is in `.yardopts`, FR-1); the step adds only the option that keeps a cache from being read.

**Must:**
- Fail on any warning and show it (AC-2.2, AC-2.6, AC-2.7, AC-2.8).
- Not check coverage (decision 3).
- Run only in the checks group (AC-2.3).

**Must not:**
- Leave a tracked or non-ignored file behind (AC-2.4).

### FR-3: Links in the included documents

The generation makes included-to-included links work, and handles the rest as decision 6 rules (AC-1.5, AC-1.6, AC-1.7, AC-2.7).

**Must:**
- Leave the documents on disk unchanged.
- Map a link by the target's path, keeping its `#fragment`.
- Leave absolute URLs (`https://…`) and in-page anchors (`#section`) as they are.
- Run in the generation only; the app doesn't load it (AC-3.7).

**Must not:**
- Print a warning for a link that resolves (a link to a missing file is the AC-2.7 case).

### FR-4: Keeping generated files and their builders out of the image

Per Story 3. **Must** be checked in RSpec (AC-3.3) and in `bin/image-smoke`.

## Non-Functional Requirements

### Performance

- The warnings step adds at most 30 s to `bin/ci checks` (AC-2.5); the spike measured about 8 s.

### Security

- The site is not published or served by the app, so no new endpoint, route or secret.
- The image is public: nothing added by this spec is in it (Story 3). The gem is development-only, so no new runtime dependency.

### Reliability

- The check is deterministic: same code, same warnings. It needs no network at run time (gems come from the bundle).
- The gem is pinned by `Gemfile.lock` and moves by Dependabot; a version that changes what warns fails the update's pull request, which fixes the comments in the same change.

### Compatibility

- Area docs and ADRs stay plain Markdown with relative links and no front matter YARD would render (spec 027 NFR).
- Ruby 4.0.7 and the bundle's pinned gems: the gem's dependencies add nothing that needs a compiler or system library on a developer machine or CI.
- Markdown: the pages and the comments are rendered as Markdown (`--markup markdown`) by YARD's own renderer, which is the first of its providers and is always present, so no gem is added for it. The spike rendered the area docs' tables and headings with it. A comment that is not legible as Markdown (the `<dir>/<file>` and `foil[,era]` layout lines of `app/models/scanner/measurement_run.rb`, which render as a stray tag and a link) is fixed with the three that warn (AC-2.1).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A comment has an unresolved `{…}` link or an unknown or malformed tag | `bin/yard doc` prints a `[warn]` line (file, line, text); `bin/ci checks` fails at the documentation step |
| A relative link in an included document points at a file that doesn't exist on disk | The generation prints a warning naming the document and the link, and the step fails (a dead link in the area docs is a documentation bug) (OD3; AC-2.7) |
| A relative link points at a file that exists on the branch but isn't on `main` yet | Accepted: existence is checked on disk, and the GitHub link works once the branch merges |
| `doc/` or `.yardoc/` exists from an earlier run | `bin/yard doc` overwrites `doc/`; `git status` stays clean; the step never reads the cache (AC-2.8) |
| An included document is added or removed (a new area doc or ADR) | The site picks it up with no change to `.yardopts` or the code (AC-1.3) |
| The gem isn't installed (a checkout without the development group) | `bin/yard` fails with Bundler's message; `bin/ci` has the gem because it runs on a full bundle. Production images never run it |
| A comment cites a spec in the old style ("spec 015 AC-2.16") | Kept as prose; no warning |
| A comment's `@see file:` names a page that doesn't exist | Not caught (YARD doesn't warn; Non-Goals) |

## Open Questions

Ruled by the maintainer on 2026-11-09: each recommendation stands. The alternatives are kept so a later change knows what was weighed, and the tags in the criteria say what an alternative would change:

- **OD1 — ADRs in the site (decision 1).** Recommended: include the numbered ADRs. Alternative: area docs only; AC-1.3, AC-1.5, AC-1.6, AC-4.2 and AC-4.4, the Glossary's "included documents" and decision 5's second example change as their tags say. The 122 links to ADRs go to GitHub under OD3's recommendation, and are dead in the site if OD3's alternative is ruled too.
- **OD2 — The `bin/ci checks` step (decision 2).** Recommended: yes, failing on any warning, about 8 s. Alternative: no step, `bin/yard doc` only; AC-2.2, AC-2.3, AC-2.5 and AC-2.8, AC-2.7's `bin/ci checks` clause, AC-4.1's `bin/ci` lines and AC-4.4's `bin/ci checks` clause, FR-2, the Performance requirement and the first two Error Scenarios rows' `bin/ci checks` part are dropped, and Story 2's goal becomes "documented, not enforced"; AC-2.1, AC-2.4 and AC-2.6 stay for `bin/yard doc`.
- **OD3 — Links to documents outside the site (decision 6).** Recommended: the generation rewrites them to GitHub's `main` and fails on a dead link. Alternative: leave them as written, and rewrite only included-to-included links; AC-1.6 and AC-2.7 change to "left as written" and "not checked".


## Out of Scope (Future Considerations)

- A coverage gate, a list of undocumented objects in CI, or a rule that new code carries comments.
- Publishing the site (GitHub Pages or elsewhere), or a docs workflow.
- Including `docs/specs/`, the ADR index or other documents as pages.
- A check that every `@see file:` names a page of the site.
- Type signatures or a type checker.
- A custom YARD theme using the design system's tokens.

## Supersedes

- [Spec 027](../027-architecture-area-docs/spec.md) **Out of Scope, "Slice B: adopt YARD"**: that bullet is a starting shape "not decided here"; the shape is decided here (`.yardopts`, `bin/yard`, `doc/`, the `bin/ci` step, the `@see` convention, and, beyond it, a link-rewriting extension and a `.yardoc/` ignore). And **the expected ADR number 0023** (D9, FR-8, AC-6.2): the YARD ADR is 0027, by the next-free-number rule those passages already state. Spec 027 is not edited.
