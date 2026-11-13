# Feature 084: The Running Version, Its Commit and the Licence, Shown in the App

**Status:** Draft
**Version:** 0.2.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 018](../018-content-notice-footer/spec.md) (the footer; frozen, by [catalog core](../../architecture/catalog-core.md)), [spec 012](../012-ghcr-registry-publishing/spec.md) and [spec 031](../031-upgrade-from-previous-release/spec.md) (the image, its CI build and its smoke test; frozen, by [release and deploy](../../architecture/release-and-deploy.md))
**Branch:** `084-version-and-licence-in-app`
**Issue:** [#374](https://github.com/plainprogrammer/Collector/issues/374) (the 1.0 milestone, housekeeping lane)
**ADR:** none. How the build passes its facts to the image is a rule of the release-and-deploy area, written in its area doc (decision 3). No decision here is costly to reverse.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-13 | The maintainer's rulings of 2026-11-13, relayed by the coordinator: decisions 2 to 5 and 8 as recommended (the version and short SHA in the licence line for everyone; three build arguments set as environment variables at the end of the final stage; the source address set at build time only, `https` only; third-party licences a later candidate whose issue the coordinator creates). New decision 9: Compose doesn't build, so a hand-built image's build arguments are documented in the README, for Compose and Kamal alike |
| 0.1.0 | 2026-11-13 | First draft from issue #374 and the task brief. Decisions 2, 3, 5 and 8 are my recommendations, sent to the coordinator as scope questions and marked *(pending)* until they are answered |

## Problem Statement

Nobody using an instance can tell which version of Collector it runs or which commit that version was built from. An operator who reports a problem or checks that an upgrade took has to look at the image tag they deployed, and that tag isn't always the release: `latest` and `edge` move. The app doesn't know these facts either. The image is built in CI from a context with no `.git` directory (`.dockerignore`), and nothing in the repository records the version: a release is only a git tag.

Collector is licensed under the GNU Affero General Public License v3.0 (`LICENSE`, `README.md`). The AGPL asks that everyone who uses the software over a network is offered the source of the version they are using. No page says what the licence is or where the source is. The footer (spec 018) carries the Wizards of the Coast notice and the Scryfall attribution, and nothing of Collector's own.

> **Terms.** *Version*: the name of the build an instance runs: a release's number (`0.3.0`), a pre-release's (`0.4.0-rc.1`), `edge` for a build of `main`, `pr-N` for a pull request's build, or `development` in a development checkout. *Revision*: the full 40-character SHA of the commit the build was made from; its *short SHA* is its first 7 characters. *Source address*: the `https` address where the source of the running build can be read. *Build facts*: the version, the revision and the source address. *Licence line*: Collector's own line in the footer. *Visitor*: someone with no session. *Collector*: a signed-in user (catalog core's terms).

## Goals

- Every page with the footer, for everyone it shows to, carries the licence line. The line names the licence, links to the licence's text, and links to the source of the running build.
- The running build's version and short SHA are on every page, in the licence line.
- The build facts get into the published image during CI's build. An image that reports no version or no SHA fails `bin/image-smoke`, so it is never published.
- A development checkout, an `edge` build, a pull request's build and an image built by hand each show a reading that says what they are.
- The licence line is the core's. The core's footer code still names no collectible, source or rights holder (`spec/footer_core_spec.rb`).

## Non-Goals

- An update check (a request to GitHub or anywhere else for a newer release), and release notes or a changelog in the app (issue #374).
- An about page, a credits page, or a licence page in the app.
- Listing third-party licences: the gems, the OCR engine, vendored JavaScript and the fonts (decision 8, a later candidate).
- A runtime setting that hides the line, the version or the SHA, or changes the source address.
- Changing the Wizards of the Coast notice, the Scryfall attribution or how a catalog type supplies them (spec 018 FR-1).
- The static error pages in `public/`, emails, and responses that aren't a full page, as spec 018's Non-Goals list them.
- Changing the image's tags, channels or OCI labels (ADR 0009).

## Users and Context

**Primary users:** an operator who reports a problem or checks that an upgrade took. A collector or visitor who wants to know what the software is and where its source is.
**Secondary users:** someone running a fork, whose instance must offer the fork's source and not the upstream's.
**Usage context:** read rarely. The line is small print at the end of every page, on phones and wide screens. Its only actions are its two links.
**User mental model:** a version line at the foot of a self-hosted app (`Gitea 1.22.0`, `Nextcloud 29`), and the "source code" link that AGPL software carries.

## Decisions

Decisions 2 to 5 and 8 were put to the maintainer as scope questions and ruled on 2026-11-13 as recommended (relayed by the coordinator); the alternatives they were chosen over are named in each. Decisions 1, 6, 7 and 9 are my calls, confirmed at Gate A.

1. **The licence line is the footer's last line, and the footer is always present.** The line follows the catalog types' lines, after a repeated line is dropped. It belongs to the core and is rendered by the core's footer code, never supplied through `.content_notice`. A page therefore always has a footer. This supersedes spec 018 AC-2.3 and FR-2's "be absent (no element) when no type supplies a notice": with no type's notice, the footer holds the licence line alone. The shell is always `c-shell--footed`.
2. **The version and short SHA are in the licence line, for everyone.** *(Ruled 2026-11-13, over: the version only for collectors, on More and the admin pages; admins only.)* The source link goes to the commit (decision 5). That link already shows a visitor which commit runs, so hiding the version from a visitor gains nothing, and one place is the easiest to find. The line's wording, by the facts known:

   | Build | Line |
   |---|---|
   | Version and revision known | "Collector 0.3.0 (a9f6de7) is free software under the AGPL-3.0. Get the source code." |
   | Version known, no revision | "Collector 0.3.0 is free software under the AGPL-3.0. Get the source code." |
   | Neither known (an image built by hand without the build facts, the test environment) | "Collector (unknown version) is free software under the AGPL-3.0. Get the source code." |

   "AGPL-3.0" links to `https://www.gnu.org/licenses/agpl-3.0.html` and "source code" links to the source address. The short SHA is text, not a link. Revision with no version doesn't occur (decision 4).
3. **The build facts are given to the image build as three build arguments and read by the app from the environment.** *(Ruled 2026-11-13.)* They are `COLLECTOR_VERSION`, `COLLECTOR_REVISION` and `COLLECTOR_SOURCE_URL`. The image sets them as environment variables in its last layer, so a new commit rebuilds only that layer and the build cache stays useful. CI's image job passes them to both of its builds: the smoke-tested one and the one pushed by digest. The pushed image must be the one that was tested. The version is `docker/metadata-action`'s version, the revision is the run's commit, and the source address is the run's repository at that commit. `compose.yaml` and `config/deploy*.yml` don't change: the image carries the facts. *Rejected:* OCI labels, because a running container can't read its own labels; a file written during the build, because `.git` isn't in the build context, so the workflow would have to write the file anyway.
4. **What each kind of build shows.** *(Ruled 2026-11-13, with decision 3.)*

   | Build | Version | Revision | Source address |
   |---|---|---|---|
   | Tag `vX.Y.Z` | `X.Y.Z` | the tag's commit | the repository at that commit |
   | Tag `vX.Y.Z-<suffix>` | `X.Y.Z-<suffix>` | the tag's commit | the repository at that commit |
   | Push to `main` | `edge` | the commit | the repository at that commit |
   | Pull request (built, never published) | `pr-N` | GitHub's merge commit | the repository at that commit |
   | Development checkout | `development` | `HEAD`, read from git once at boot | the upstream repository |
   | Test environment, or an image built without the build facts | unknown | none | the upstream repository |

   A development checkout links to the repository, not to the commit, because its commit may not be pushed. The test environment never reads git, so a page's text doesn't depend on the checkout.
5. **The source link goes to the source of the running build, and a fork's build points at the fork.** *(Ruled 2026-11-13, over: a runtime setting; a fixed upstream address.)* The source address is given whole at build time: the app never builds a forge's path from parts, so a fork on any forge passes its own address. CI passes its own repository's address, so a fork that builds through the workflow gets its own link with no setup. With no address given, the link goes to `https://github.com/plainprogrammer/Collector`. There is no runtime setting: the source offered must match the code that runs, and someone who changes the code builds their own image.
6. **Untrusted facts fall back, never break the page.** A version must be 1 to 64 characters of letters, digits, `.`, `+`, `-` and `_`. A revision must be 40 hexadecimal characters. A source address must be an absolute `https` URI with a host. A fact that fails its rule is treated as not given (decisions 2 and 5). All three are escaped when rendered.
7. **The smoke test proves an image reports its facts.** `bin/image-smoke` reads the sign-in page of the image it boots and fails unless the licence line shows a version other than "unknown version" and a 7-character SHA. CI passes the build facts (decision 3), so a published image always has them. An image built by hand without them fails the smoke test, and the README says how to pass them.
8. **Third-party licences are a later candidate.** *(Ruled 2026-11-13.)* A new issue, which the coordinator creates from this spec's draft, and a roadmap row: list the licences of the gems, the OCR engine, vendored JavaScript and the fonts that ship in the image. This spec covers Collector's own licence only.
9. **A hand-built image gets its build facts from the documented build command, not from Compose or Kamal's configuration.** `compose.yaml` never builds: it runs `COLLECTOR_IMAGE`, the published image by default, and the README's "Building from source" builds a local image with `docker build` before Compose runs it. That command is where the facts go, so the README gives it with the three `--build-arg` flags (the version a builder chooses, `git rev-parse HEAD`, and their source address), and `compose.yaml`'s comment points to it instead of repeating a bare `docker build`. Kamal's own-registry path builds through Kamal's `builder:`, so the README shows the `builder: args:` lines to add to `config/deploy.yml`; the stock `config/deploy.yml` deploys the published image (`--skip-push`) and stays unchanged. A build that leaves them out is not silent: its footer reads "unknown version" and `bin/image-smoke` fails it (decision 7). *Rejected:* a `build:` section in `compose.yaml` that passes the arguments, because the Compose path is the published image and a second way to build would need its own documentation and smoke; a `builder: args:` block in the stock `config/deploy.yml`, because the stock path never builds and the file is the operator's to edit.

## User Stories

### Story 1: The licence line is on every page, for everyone

**As an** operator of an instance
**I want** every page to say that Collector is AGPL-3.0 software and where its source is
**So that** the instance offers its source to everyone who uses it over the network, as the AGPL asks

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector When they open the collection page, a card page, the deck page, the scanner page, the More page or an admin page (a representative list; the rule is every page, as spec 018's glossary defines it) Then the page's footer contains the licence line as its last paragraph, after the catalog types' lines.
- [ ] **AC-1.2** Given a visitor When they open the sign-in page, or the first-run or open sign-up page Then the footer contains the licence line.
- [ ] **AC-1.3** Given the open catalog (`:public_catalog`) and a visitor When they open catalog search and a card page Then the footer contains the licence line.
- [ ] **AC-1.4** Given any page When its licence line is read Then "AGPL-3.0" is a link to `https://www.gnu.org/licenses/agpl-3.0.html` and "source code" is a link to the source address. No other part of the line is a link, and neither link has a `target` attribute.
- [ ] **AC-1.5** Given no registered catalog type supplies a content notice When any page is opened Then the page has one footer, holding the licence line alone, and the shell is `c-shell--footed` (supersedes spec 018 AC-2.3).
- [ ] **AC-1.6** Given any page, including a form re-rendered with 422 When it is rendered Then the licence line appears exactly once.
- [ ] **AC-1.7** Given a request that isn't answered with the application layout (a `Turbo-Frame` request, a Turbo Stream answer, the health check) When it is answered Then it contains no licence line.
- [ ] **AC-1.8** Given the core's footer code, with whatever code supplies the licence line and the build facts added to `spec/footer_core_spec.rb`'s list of files When it is searched for "mtg", "magic", "wizards", "scryfall" and "fan content", case-insensitively Then none is found.

### Story 2: The version and commit are shown

**As an** operator reporting a problem or checking an upgrade
**I want** to read the running version and the commit it was built from
**So that** I can say exactly what runs, and see that an upgrade took

**Acceptance criteria:**

- [ ] **AC-2.1** Given the build facts version `0.3.0`, a 40-character revision and a source address When any page is opened, signed in or not Then the licence line reads "Collector 0.3.0 (<the revision's first 7 characters>) is free software under the AGPL-3.0. Get the source code." and "source code" links to the given address.
- [ ] **AC-2.2** Given the version `edge` and a revision When a page is opened Then the line reads "Collector edge (<short SHA>) …".
- [ ] **AC-2.3** Given a version and no revision When a page is opened Then the line reads "Collector 0.3.0 is free software under the AGPL-3.0. Get the source code.", with no parentheses.
- [ ] **AC-2.4** Given no build facts When a page is opened in the test environment Then the line reads "Collector (unknown version) is free software under the AGPL-3.0. Get the source code." and "source code" links to `https://github.com/plainprogrammer/Collector`.
- [ ] **AC-2.5** Given the development environment, no build facts and a checkout whose `HEAD` is a known commit When the build facts are read Then the version is `development` and the revision is `HEAD`'s, and the source address is the upstream repository's.
- [ ] **AC-2.6** Given the development environment and no git (git missing, not a checkout, or the command fails) When the build facts are read Then the version is `development`, there is no revision, and nothing raises.
- [ ] **AC-2.7** Given a version that breaks decision 6's rule (empty, over 64 characters, or holding a space, `<` or another character outside the rule) When a page is opened Then the line reads as if no version were given.
- [ ] **AC-2.8** Given a revision that isn't 40 hexadecimal characters When a page is opened Then the line shows no SHA.
- [ ] **AC-2.9** Given a source address that isn't an absolute `https` URI with a host (`http://…`, `javascript:…`, a relative path) When a page is opened Then "source code" links to `https://github.com/plainprogrammer/Collector`.
- [ ] **AC-2.10** Given any build facts When they are read for a page Then reading them runs no database query and no outbound request, and git is never run outside the development environment.

### Story 3: The image carries its build facts

**As the** maintainer publishing a release
**I want** every image CI builds to know its version, revision and source
**So that** an instance on any published image shows them with no setting

**Acceptance criteria:**

- [ ] **AC-3.1** Given the `Dockerfile` When it is read Then its final stage takes `COLLECTOR_VERSION`, `COLLECTOR_REVISION` and `COLLECTOR_SOURCE_URL` as build arguments and sets them as environment variables, after every `COPY`, so that no earlier layer depends on them.
- [ ] **AC-3.2** Given CI's image job When it is read Then both of its builds (Build, and Push by digest) pass the same three build arguments: the version from `docker/metadata-action`, the run's commit, and the run's repository at that commit.
- [ ] **AC-3.3** Given an image built with the three build arguments When `bin/image-smoke` runs on it Then it passes, having found on the sign-in page a licence line with the given version and the revision's short SHA.
- [ ] **AC-3.4** Given an image built without the build arguments When `bin/image-smoke` runs on it Then it fails, saying that the image reports no version or no revision and naming the build arguments.
- [ ] **AC-3.5** Given a pull request's CI run When the image job runs Then `bin/image-smoke` passes on both architectures (the run's evidence is recorded in `verification.md`).

### Story 4: The footer still fits every screen

**As a** collector
**I want** the longer footer to stay legible small print
**So that** it is there when I look for it and out of the way when I don't

**Acceptance criteria:**

- [ ] **AC-4.1** Given a viewport 360px wide When any page is opened Then the licence line wraps inside the page gutter with no horizontal scrolling, and the footer still clears the tab bar when the page is scrolled to its end (spec 018 AC-3.1, AC-3.2).
- [ ] **AC-4.2** Given the light and the dark theme When the footer is rendered Then the licence line holds at least 4.5:1 contrast, and its links are brand links with the focus ring, as the other footer links are (spec 018 AC-3.4, AC-3.8).
- [ ] **AC-4.3** Given the scanner page When it is opened in a browser Then the footer shows the licence line, and the page's Content-Security-Policy is unchanged (spec 018 AC-4.1, AC-4.2).
- [ ] **AC-4.4** Given the design system's documentation When this feature is merged Then `docs/design-system/components/Footer.md` shows the licence line in its markup, and states that the footer is always present.

### Story 5: The documents agree

**As an** operator or contributor
**I want** the README, the release procedure, the area docs and `CLAUDE.md` to say where the version comes from
**So that** a hand-built image and a fork show the right facts

**Acceptance criteria:**

- [ ] **AC-5.1** Given `README.md` When it is read Then its Self-hosting section says where an instance shows its version and commit, and how to pass the three build arguments when building an image by hand: the "Building from source" command with its `--build-arg` flags, and the `builder: args:` lines for Kamal's own-registry path, each with a fork's source address (decision 9). Its License section mentions the footer's line.
- [ ] **AC-5.2** Given `docs/releasing.md` When it is read Then it says that every image CI builds carries the build facts, what each trigger's version is (decision 4), and a step after a release: check that the deployed instance's footer shows the release's version and SHA.
- [ ] **AC-5.3** Given `docs/architecture/release-and-deploy.md` and `docs/architecture/catalog-core.md` When they are read Then the first holds the build facts' rules (decisions 3, 4, 6 and 7) and the second the footer's licence line and its place (decisions 1, 2 and 5), each with this spec as its source, and the superseded spec 018 rule is gone.
- [ ] **AC-5.4** Given `CLAUDE.md` and `docs/specs/README.md` When they are read Then `CLAUDE.md` names the licence line and the build facts in its Project Status, and the index has spec 084's row with its supersession of spec 018 AC-2.3, in both directions.
- [ ] **AC-5.5** Given `docs/roadmap.md` When it is read Then the housekeeping lane has #374's row, and decision 8's later candidate has its own row and issue.
- [ ] **AC-5.6** Given `compose.yaml` When it is read Then it has no `build:` section, and its comment on `COLLECTOR_IMAGE` points to the README's "Building from source" instead of giving a bare `docker build` command (decision 9).

## Functional Requirements

### FR-1: The licence line

**Must:**
- Be the footer's last line, on every page the footer is on, for everyone (decision 1, AC-1.1 to AC-1.3).
- Read as decision 2's table, with two links: "AGPL-3.0" and "source code" (AC-1.4, AC-2.1 to AC-2.4).
- Be built by core code that names no collectible (AC-1.8).
- Use the footer's existing look: the line is a paragraph like the others, and its links are the footer's links.

**Must not:**
- Come through a catalog type's `.content_notice`, or be dropped as a repeat of a type's line.
- Query the database, read a file or call out while a page renders (AC-2.10).
- Add a logo, icon, button or a new design-system pattern.

### FR-2: The build facts

**Must:**
- Come from the environment variables `COLLECTOR_VERSION`, `COLLECTOR_REVISION` and `COLLECTOR_SOURCE_URL` (decision 3), and in development with none set, from git as decision 4 says.
- Be read once per process and kept, since they can't change while it runs.
- Fall back as decision 6 says, without raising, on any value (AC-2.7 to AC-2.9).
- Have one reader that every caller uses: the footer and `bin/image-smoke`'s check read the same facts.

**Must not:**
- Run git outside the development environment, or anywhere during a request.
- Be a runtime setting an operator is told to set: the image sets them. The README names them only for building an image.

### FR-3: The image and CI

**Must:**
- Declare the three build arguments in the `Dockerfile`'s final stage after its `COPY` steps (AC-3.1), with empty defaults.
- Pass the same values to both builds in the image job (AC-3.2). They are the only changes to `.github/workflows/ci.yml`.
- Extend `bin/image-smoke` with decision 7's check (AC-3.3, AC-3.4).

**Must not:**
- Change the image's tags, its labels, `config/deploy*.yml`, or `compose.yaml` beyond its comment (decision 9).
- Put `.git` into the build context.

## Non-Functional Requirements

### Performance

- The line adds no database query, no HTTP request and no asset. The facts are read once per process.

### Security

- The build facts are escaped and checked (decision 6). An address that isn't `https` is never rendered as a link.
- Showing the version to visitors is accepted (decision 2). The source of every release is public, and the source link the AGPL asks for names the commit anyway.
- The scanner pages' Content-Security-Policy is unchanged (AC-4.3).

### Accessibility

- The line is text with two inline links in the footer's `contentinfo` landmark. The links' names are their words, which say where they lead.

### Hosted-door rules

- Source terms: no source is touched. Operator is not the user: no collection data is shown. Collector choices: none stored. Bounded cost: no query, nothing stored.
- Export: no collector-owned data is added, so the export format is unchanged.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| No build facts, in production | "Collector (unknown version)", no SHA, link to the upstream repository. The smoke test fails such an image (AC-2.4, AC-3.4) |
| A version, revision or address breaks decision 6's rule | It is treated as not given (AC-2.7 to AC-2.9) |
| Development checkout without git, or git fails | Version `development`, no SHA, nothing raises (AC-2.6) |
| A fork builds through the same workflow | Its own repository and commit are the source address (decision 5) |
| A fork builds by hand and passes no source address | The link goes to the upstream repository. The README tells a fork to pass its own (AC-5.1) |

## Open Questions

None. The scope questions were ruled on 2026-11-13.

## Out of Scope (Future Considerations)

- Third-party licences (decision 8's candidate).
- An update check and release notes in the app (issue #374).
- A runtime override of the source address for an operator who serves the source elsewhere.
