# Feature 054: Browsable API Documentation for the Ruby Code, with the Area Docs and ADRs Linked In (YARD)

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `054-adopt-yard`
**Issue:** [#103](https://github.com/plainprogrammer/Collector/issues/103) (spec 027 slice B)
**ADR:** 0027 (YARD), written with this spec's plan. The issue and [spec 027](../027-architecture-area-docs/spec.md) say "ADR 0023"; that number is taken ([0023](../../adr/0023-locations-make-export-format-version-2.md)), and 0024–0026 were taken after it, so the YARD ADR takes the next free number, 0027, as the [ADR index](../../adr/README.md) allows

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-09 | Written from issue #103, the starting shape in spec 027's Out of Scope ("Slice B: adopt YARD") and a measured spike of YARD 0.9.45 on the current code (Problem Statement). Decisions 1, 2 and 6 are recommendations for the maintainer to rule on (Open Questions) |

---

## Problem Statement

A developer or an agent who wants to know what a Ruby class in `app/` or `lib/` is for, or which method to call, reads source files one at a time. The comments that exist (about 54% of the classes, modules, constants and methods carry one) are only reachable that way, and the current architecture, which [spec 027](../027-architecture-area-docs/spec.md) put into [area docs](../../architecture/README.md) and [ADRs](../../adr/README.md), is in Markdown files that no tool links to the classes they describe. Spec 027 left this as slice B: a generated, browsable site of the Ruby API with the area docs linked in, which nothing generated is committed or shipped for.

A spike on the current code (YARD 0.9.45, run outside the repository, nothing committed) measured the starting point:

- `app/` and `lib/` give 197 files, 61 modules, 210 classes, 838 methods, 53.7% documented; the run takes about 8 s.
- It gives **3 warnings**: `{name,collector}` in `app/models/scanner/measurement_run.rb:4` and `{id}` twice in `lib/collector/ghcr_cleanup.rb:107,120` are read as YARD links and don't resolve. Nothing else warns, so a no-warnings rule can start at zero.
- With the 7 area docs and the 27 ADRs as extra pages the site is 5.6 MB and the tables in the area docs render.
- The relative links inside those pages do **not** resolve in the site: the area docs link each other as `tenancy-and-accounts.md`, ADRs as `../adr/0024-….md` and specs as `../specs/…`, but YARD names its pages `file.<name>.html`. Spec 027's NFR keeps the area docs plain Markdown with relative links so they read well on GitHub, so the links have to be made to work at generation, not in the files (decision 6).

### Glossary

- **The site**: the HTML YARD generates into `doc/`.
- **Included documents**: the pages added to the site besides the API reference: the area docs and, if decision 1 is ruled in, the ADRs.
- **Warning**: a line YARD prints beginning `[warn]`, such as an unresolved link, an unknown tag or a malformed tag.

## Goals

- One command generates the site from `app/` and `lib/` with the included documents as pages, and the area map is its front page.
- A comment that makes YARD warn fails CI; the code on `main` today builds with no warnings.
- Nothing YARD generates (`doc/`, `.yardoc/`) can be committed, and neither it nor anything that only builds it is in the published image; `bin/image-smoke` fails an image that holds any of it.

## Non-Goals

- Documentation **coverage** (a minimum percentage, or `yard stats --list-undoc` as a gate). At 53.7% most of the code is undocumented; a gate would need comments written for their own sake. A later spec may add one.
- Writing or rewriting comments beyond the three that warn. Existing "spec NNN AC-x" comments stay as they are (spec 027's starting shape).
- Publishing or hosting the site (GitHub Pages, the image, a container). It is generated locally and in CI's check only.
- Rendering `docs/specs/`, `docs/lessons/`, `docs/design-system/`, `README.md` or any other document as a page (decision 1 and 6 say how links to them behave).
- Changing the area docs' shape or their relative links (spec 027 NFR "Compatibility"), or the `Dockerfile` or its build.
- Type annotations (`@param [Type]`) on existing methods, or a type checker.

## Users and Context

**Primary users:** the maintainer and agents (Claude Code sessions) who read, change and review the Ruby code.
**Secondary users:** contributors reading the repository.
**Usage context:** before changing a class, a reader opens the site and finds the class's comment, its methods, and the area doc and ADRs that explain the subsystem; when a comment is added or edited, the contributor runs the command or sees CI's check.
**User mental model:** "the API docs" are generated from the code's comments and never stored; the architecture is in the area docs; the site links the two.

## Decisions

### 1. The ADRs are included pages (recommendation; the maintainer rules)

**Recommendation: include them.** The area docs cite ADRs on almost every page (the release and deploy area doc alone links 12), and a reader following such a citation inside the site should land on the ADR and not on a dead link. The cost measured in the spike is 27 more pages and under 1 MB. **Alternative:** area docs only, with ADR links pointing at GitHub (decision 6); smaller site, but the reason for each choice is a click away from the code that follows it.

### 2. Warnings are checked by a `bin/ci` step (recommendation; the maintainer rules)

**Recommendation: a step in `bin/ci checks`**, after the Ruby style step, running the same command a developer runs but failing on a warning and writing nothing into the checkout that isn't ignored. It adds about 8 s to `checks` (the spike's time, measured on the maintainer's machine) and runs wherever `bin/ci checks` runs: the pre-push hook for documentation-only branches, `bin/ci`, and GitHub's checks job. **Alternative:** a command only (`bin/yard`), unchecked; a warning then goes unseen until someone generates the site, and the count rises from zero. The step's one-time cost is also its worth: a comment edit that breaks a link is found in the pull request that made it.

### 3. Coverage is not checked, and private and protected methods stay hidden

YARD's defaults stand: undocumented objects appear (as undocumented), private and protected methods are hidden. No coverage number is recorded or gated (Non-Goals).

### 4. The front page is the area map

The site's front page is `docs/architecture/README.md` (the map of the areas), not the repository's `README.md`, which describes installing and running the app and has no place in an API reference. YARD would otherwise take the repository `README.md` as the front page when none is named.

### 5. Comment convention

Existing comments naming a spec and criterion ("spec 015 AC-2.16") are kept. A comment written or edited after this spec that cites a spec or an area doc writes the citation as an `@see` tag naming it, so the site lists it apart from the prose. The convention is written where agents read conventions, not enforced by a check (a tag-by-tag check is the coverage kind of gate, Non-Goals).

### 6. Links in the included documents work in the site (recommendation; the maintainer rules)

A relative link from an included document to another included document (area doc to area doc, area doc to ADR, ADR to ADR) opens that page in the site. **Recommendation:** every other relative link in an included document (a spec, `docs/releasing.md`, `docs/design-system/`, a source file) becomes a link to that file on GitHub's `main` branch in the site, so no link in the site is dead. The files keep their relative links (spec 027 NFR) and nothing is rewritten on disk: the rewriting is part of generation. **Alternative:** rewrite only the included-to-included links and leave the rest as they are, dead in the site and live on GitHub. The recommendation costs a small amount of code that is itself in the API reference and needs its own tests; the alternative costs nothing and leaves about half of the links in the area docs dead in the site.

## User Stories

All criteria that name a command are verified by running it and recording its output in `verification.md`; the criteria about documents are verified by reading, per `.claude/rules/testing.md`. Criteria about the repository's configuration files (`.gitignore`, `.dockerignore`) are checked in RSpec as the existing ones are (`spec/image_publishing_spec.rb`); criteria about the extension that rewrites links have unit specs.

### Story 1: A reader browses the Ruby API with the architecture beside it

**As a** developer or agent changing the Ruby code
**I want** one command to generate a browsable site of the classes with the area docs (and ADRs) as pages
**So that** I find what a class is for, and the subsystem it belongs to, without reading source files one at a time

**Acceptance criteria:**

- [ ] **AC-1.1** Given a checkout with the development gems installed When `bin/yard doc` runs Then it exits 0, prints no `[warn]` line, and writes `doc/index.html` (the site)
- [ ] **AC-1.2** Given the site When its class list is read Then it has a page for every class and module in `app/` and `lib/` that YARD finds (for example `Lot`, `Collector::Backup`, `MTG::Art::Operation`), and none for `spec/`, `config/`, `db/`, `script/` or `vendor/`
- [ ] **AC-1.3** Given the site When its file list is read Then it has a page for each of the 7 area docs and, if decision 1 is ruled in, for each ADR, with their headings, tables and code blocks rendered as HTML
- [ ] **AC-1.4** Given the site When its front page is opened Then it shows the area map (`docs/architecture/README.md`), not the repository's `README.md`
- [ ] **AC-1.5** Given the site When a link in an area doc to another area doc, or to an ADR (if included), is followed Then it opens that page in the site
- [ ] **AC-1.6** Given the site When a link in an included document to a document that isn't included (a spec, `docs/releasing.md`) is followed Then, if decision 6's recommendation is ruled in, it opens that file on GitHub's `main` branch; otherwise it is left as written
- [ ] **AC-1.7** Given the area docs and ADRs on disk When the site has been generated Then `git status` shows no change to any of them (the links are rewritten in the site only)
- [ ] **AC-1.8** Given a second run When `bin/yard doc` runs again with no change Then it exits 0 with no `[warn]` line and the same pages

### Story 2: A comment that warns is caught before it merges

**As a** maintainer
**I want** CI to fail when a comment makes YARD warn
**So that** the documentation stays buildable and the warning count stays at zero

**Acceptance criteria:**

- [ ] **AC-2.1** Given the code at the branch's head When `bin/yard doc --fail-on-warning` (or the step's own command) runs Then it exits 0: the three comments that warn today (`app/models/scanner/measurement_run.rb:4`, `lib/collector/ghcr_cleanup.rb:107` and `:120`) no longer do, and their text still says what it said
- [ ] **AC-2.2** Given a comment with an unresolved link (for example `{nothing_here}`) or a malformed tag (for example a `@param` with no name) in `app/` or `lib/` When `bin/ci checks` runs Then the documentation step fails, names the file and line YARD printed, and `bin/ci` exits non-zero; with the comment reverted it passes. The run is recorded in `verification.md`
- [ ] **AC-2.3** Given decision 2's recommendation When `config/ci.rb` is read Then the step is in the group that `bin/ci checks` runs and not in the RSpec group, and is not added to the container image smoke or the shards
- [ ] **AC-2.4** Given the step has run in a checkout When `git status --ignored` is read Then everything it wrote is in an ignored path (`doc/`, `.yardoc/` or `tmp/`) and nothing is tracked or untracked-and-unignored
- [ ] **AC-2.5** Given the step When its run time is read from `bin/ci checks` output on the branch's CI run Then it is at most 30 s
- [ ] **AC-2.6** Given the step fails on a bad comment When the developer reads its output Then it prints YARD's warning lines (file, line and the text), not only an exit status

### Story 3: Nothing generated is committed or shipped

**As a** maintainer of a public container image
**I want** the generated site and everything that only builds it kept out of Git and out of the image
**So that** the repository stays source-only and the image carries only what it runs (spec 012, ADR 0008)

**Acceptance criteria:**

- [ ] **AC-3.1** Given a generated `doc/` and `.yardoc/` When `git status` is read Then neither shows (both are in `.gitignore`)
- [ ] **AC-3.2** Given `.dockerignore` When it is read Then it excludes `/doc`, `/.yardoc`, `/.yardopts`, `bin/yard` (and `bin/yardoc` if the binstubs make it) and every other file this feature adds that nothing in the image runs, each with a comment in the file's style saying why
- [ ] **AC-3.3** Given `bin/image-smoke`'s list of paths that must be absent from the image When it is read Then it names each path of AC-3.2 that can exist in a build context, and an image that holds any of them fails the smoke
- [ ] **AC-3.4** Given the image's bundle When its gems are listed Then `yard` is not in it (the gem is in the development group only, which the image's build leaves out)
- [ ] **AC-3.5** Given the Gemfile and `Gemfile.lock` When they are read Then `yard` (and a markdown processor, if the plan needs one) are added by editing the Gemfile and running `bundle install`, in the development group with `require: false`, and `bin/bundler-audit` passes
- [ ] **AC-3.6** Given an image built from the branch When `bin/image-smoke` runs Then it passes. Checked in CI's image job; locally only if a container engine is at hand

### Story 4: The documentation records and explains it

**As an** agent about to touch the Ruby comments or the image's contents
**I want** the commands, the rule and the decision written where I read them
**So that** I run the right command and don't re-decide it

**Acceptance criteria:**

- [ ] **AC-4.1** Given `CLAUDE.md`'s Commands list When it is read Then it names `bin/yard doc`, what it writes (`doc/`), and that `bin/ci checks` fails on a warning, in one line each of the existing style, and the Project Status paragraph is not extended
- [ ] **AC-4.2** Given `docs/adr/0027-yard-for-api-documentation.md` When it is read Then it has the ADR sections in their order, Status `Accepted`, the choice of YARD (against RDoc and no generated docs), the markup processor chosen, the decisions 1, 2 and 6 as ruled, and the consequences; `docs/adr/README.md` has its index row (under a heading that fits) and its "Expected" paragraph no longer lists YARD
- [ ] **AC-4.3** Given `docs/architecture/release-and-deploy.md` When it is read Then its image statements ("The image carries only what it runs", "`bin/image-smoke` fails an image that…") list the paths of AC-3.2 and AC-3.3, with this spec as their source, and its Sources and Distillation log are updated per the documentation rules
- [ ] **AC-4.4** Given `.claude/rules/conventions.md` (or the file that holds comment conventions) When it is read Then it states the comment convention of decision 5 and that a comment with an unresolved `{…}` fails `bin/ci checks`
- [ ] **AC-4.5** Given `docs/architecture/README.md` When it is read Then it says the area docs are also pages of the generated site (how to build it) and still has plain relative links (spec 027 NFR)
- [ ] **AC-4.6** Given `docs/specs/README.md` and `docs/roadmap.md` When they are read Then the index has this spec's row (Draft until approved, then per the documentation rules) and spec 027's row lists "Out of Scope 'Slice B' (the starting shape) and D9's and FR-8's expected ADR number 0023: 054 (0027)" under Superseded by, and this spec's row lists the same under Supersedes; the roadmap's #103 line names this spec and ADR 0027
- [ ] **AC-4.7** Given the supersession of AC-4.6 When this spec is read Then it records it ("Supersedes", below), and spec 027's file is not edited

## Functional Requirements

### FR-1: The command

`bin/yard` is a binstub of the `yard` gem; `bin/yard doc` generates the site.

**Must:**
- Read its options from `.yardopts` at the repository root (so a plain `yard doc` and an editor's tool behave the same): sources `app` and `lib`; the included documents (decision 1); the front page (decision 4); the output directory `doc/`.
- Treat `.yardopts` as the one definition of what goes in the site.

**Must not:**
- Require a running app, a database, a network or a container engine.
- Write anywhere that isn't ignored by Git (AC-2.4).

### FR-2: The warnings check

A step in `config/ci.rb` (decision 2) generates the site and fails when YARD prints a warning.

**Must:**
- Fail on any warning and show it (AC-2.2, AC-2.6).
- Not check coverage (decision 3).
- Run only in the checks group (AC-2.3).

**Must not:**
- Leave a tracked or non-ignored file behind (AC-2.4).

### FR-3: Links in the included documents

The generation makes included-to-included links work, and handles the rest as decision 6 rules (AC-1.5, AC-1.6, AC-1.7).

**Must:**
- Leave the documents on disk unchanged.
- Map a link by the target's path, so `../adr/0024-backup-with-vacuum-into.md#consequences` keeps its fragment.
- Leave absolute URLs (`https://…`) and in-page anchors (`#section`) as they are.

**Must not:**
- Print a warning for a link it handles.

### FR-4: Keeping generated files and their builders out of the image

Per Story 3. **Must** be checked in RSpec where the repository's other `.dockerignore` rules are (`spec/image_publishing_spec.rb`) and in `bin/image-smoke`.

## Non-Functional Requirements

### Performance

- The warnings step adds at most 30 s to `bin/ci checks` (AC-2.5); the spike measured about 8 s.

### Security

- The site is not published or served by the app, so no new endpoint, route or secret.
- The image is public: nothing added by this spec is in it (Story 3). The gem is development-only, so no new runtime dependency.

### Reliability

- The check is deterministic: same code, same warnings. It needs no network at run time (gems come from the bundle).
- A new YARD release that changes what warns is picked up with the gem's version, in a `chore(deps)` commit that fixes the new warnings, as for Brakeman (`.claude/memory/brakeman-ensure-latest.md`).

### Compatibility

- Area docs and ADRs stay plain Markdown with relative links and no front matter YARD would render (spec 027 NFR).
- Ruby 4.0.7 and the bundle's pinned gems: the gem's dependencies add nothing that needs a compiler or system library on the developer machine or CI. [NEEDS CLARIFICATION: the markup processor for Markdown pages and comments. The spike rendered the area docs' tables with the processor YARD found on its own (RDoc's, already in the bundle); the plan confirms it renders every included document correctly, or adds a gem, and ADR 0027 records the choice. Not a product question.]

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A comment has an unresolved `{…}` link or an unknown or malformed tag | `bin/yard doc` prints a `[warn]` line (file, line, text); `bin/ci checks` fails at the documentation step |
| A relative link in an included document points at a file that doesn't exist | The generation prints a warning naming the document and the link, and the step fails (a dead link in the area docs is a documentation bug) |
| `doc/` or `.yardoc/` exists from an earlier run | `bin/yard doc` overwrites it; `git status` stays clean; the step never reads the cache (a stale cache can't hide a warning) |
| An included document is added or removed (a new area doc or ADR) | The site picks it up with no change to `.yardopts` or the code |
| The gem isn't installed (a checkout without the development group) | `bin/yard` fails with Bundler's message; `bin/ci` has the gem because it runs on a full bundle. Production images never run it |
| A comment cites a spec in the old style ("spec 015 AC-2.16") | Kept as prose; no warning |

## Open Questions

For the maintainer, at spec approval:

- **OD1 — ADRs in the site (decision 1).** Recommended: include them. Alternative: area docs only, ADR links to GitHub.
- **OD2 — The `bin/ci checks` step (decision 2).** Recommended: yes, failing on any warning, about 8 s. Alternative: no step; `bin/yard doc` only.
- **OD3 — Links to documents outside the site (decision 6).** Recommended: the generation rewrites them to GitHub's `main`; alternative: leave them as written.

The markup processor (Non-Functional, Compatibility) is for the plan and ADR 0027, not the maintainer.

## Out of Scope (Future Considerations)

- A coverage gate, a list of undocumented objects in CI, or a rule that new code carries comments.
- Publishing the site (GitHub Pages or elsewhere), or a docs workflow.
- Including `docs/specs/` or other documents as pages.
- Type signatures or a type checker.
- A custom YARD theme using the design system's tokens.

## Supersedes

- [Spec 027](../027-architecture-area-docs/spec.md) **Out of Scope, "Slice B: adopt YARD"** (the starting shape: `.yardopts`, `bin/yard`, `doc/`, the `bin/ci` check and the `@see` convention are now decided here), and its decision D9 and FR-8's **expected ADR number 0023**: the YARD ADR is 0027. Spec 027 is not edited.
