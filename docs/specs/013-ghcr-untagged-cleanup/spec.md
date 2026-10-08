# Feature 013: Clean Up Untagged GHCR Package Versions

**Status:** Approved
**Version:** 1.1.0
**Created:** 2026-10-08
**Last Updated:** 2026-10-08
**Branch:** `013-ghcr-untagged-cleanup`
**Issue:** [#17](https://github.com/plainprogrammer/Collector/issues/17)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-08 | Initial draft from the approved [prd.md](prd.md) and ADR [0011](../../adr/0011-own-ghcr-cleanup-script.md). Approved by the maintainer |
| 1.1.0 | 2026-10-08 | Spec review revisions (Fable, Mode A). **Post-delete check** also confirms every child digest of every tag is still fetchable, because deleting a child leaves its index intact (AC-2.4, FR-4); the check is part of the command. **Manifest reads** specified: by digest, anonymous pull token, `Accept` header, list vs single-image media types (FR-1, AC-3.4, AC-3.5). **Overlapping orphan units** merge; children missing from the version list are ignored; a unit deletes its list first (Terms, FR-1, NFR Reliability). **Pagination** by `page` on the `/users/…` path, not the `Link` header (FR-3, AC-3.2). **Token** variable `GH_TOKEN`, falling back to `GITHUB_TOKEN` (AC-3.7, FR-3). **Workflow** jobs `dry-run` and `delete` with conditions, permissions and a Sunday 06:00 UTC cron (FR-4). **Delete 404** means already deleted and the run continues; other refusals stop it (AC-3.6, maintainer's ruling). **Also:** names (`Collector::GhcrCleanup`), exact grace boundary, disjoint counts, malformed list, platform check on every tagged list before deleting (AC-3.8), AC-4.3 checkable any day, timeouts, preview status of token deletion |

---

## Problem Statement

Every publish to `ghcr.io/plainprogrammer/collector` (spec 012) pushes two per-architecture images untagged, by digest, and then a tagged manifest list that references them. A re-run of a release leaves the previous manifest list untagged. Nothing removes orphaned versions, so they accumulate: on 2026-10-08 the package had 18 versions, 13 untagged.

Most untagged versions are not garbage. Ten of those 13 are the per-architecture children of the five tagged manifest lists; deleting them breaks those tags for every self-hoster. Only three (one manifest list orphaned by a release re-run, and its two children) are safe to delete. This feature removes orphans on a schedule without ever breaking a tag.

> **Inputs.** Scope and decisions come from the approved [prd.md](prd.md) and the accepted [ADR 0011](../../adr/0011-own-ghcr-cleanup-script.md) (a cleanup script in this repository, stdlib-only, rather than a third-party action). The registry (GHCR), its package API (GitHub's REST packages API), the scheduler (GitHub Actions) and the publish flow of spec 012 / ADR 0010 are fixed inputs, so this spec names them. The command name `bin/ghcr-cleanup` is user-facing and is named here too.
>
> **Terms.**
> - A *version* is one entry in the package's version list: a digest, a creation time, and zero or more tags.
> - A version is *tagged* when the packages API reports at least one tag for it (`metadata.container.tags` non-empty). One version can carry several tags (the release list carries `latest`, `0.1` and `0.1.0`).
> - A *manifest list* is a version whose manifest has a *list media type*: `application/vnd.oci.image.index.v1+json` or `application/vnd.docker.distribution.manifest.list.v2+json`. Its *children* are the digests it references. A *single image* has a *single-image media type*: `application/vnd.oci.image.manifest.v1+json` or `application/vnd.docker.distribution.manifest.v2+json`. Any other media type is *unknown*.
> - A digest is *referenced* when a tagged manifest list names it as a child.
> - An *orphan unit* is an untagged manifest list together with those of its children that are in the version list, untagged and not referenced; any other untagged, unreferenced version is an orphan unit on its own. Orphan units that share a member are one unit (their union). A child digest that is not in the version list is ignored when forming units (it is already gone). A unit's *age* is the age of its newest member.
> - A version's *age* is the run's start time (read once per run) minus the version's `created_at` from the packages API. The *grace period* is 7 days; a unit is *past the grace period* when its age is strictly more than 7 × 86,400 seconds.
> - A *dry run* reports what a deleting run would delete and deletes nothing.

## Goals

- Untagged versions that no tagged manifest list references are deleted once their orphan unit is older than the grace period.
- No tagged version, and no digest a tagged manifest list references, is ever deleted.
- The cleanup fails closed: when anything it relies on can't be read or understood, it deletes nothing (or nothing further) and the run fails, naming the cause.
- The cleanup runs weekly without anyone acting, and on demand, with a dry run as the default for manual and local runs.
- Every tag still resolves to exactly `linux/amd64` and `linux/arm64` after a deleting run, and the run checks it.
- The selection rule is covered by the test suite that `bin/ci` runs.

## Non-Goals

- Deleting tagged versions, including old `sha-*` tags or old releases.
- Changing how `ci.yml` builds, tags or publishes images.
- Cleaning up any package other than `ghcr.io/plainprogrammer/collector`.
- Attestations, provenance or SBOM entries (deferred by ADR 0008).
- A configurable grace period or schedule beyond the defaults here.

## Users and Context

**Primary users:** the maintainer, who reads the package page to see what is published and wants it to list only what matters, and who can run the cleanup by hand.
**Secondary users:** self-hosters pulling `latest`, `X.Y.Z`, `X.Y`, `edge` or `sha-*`, who must never notice the cleanup.
**Usage context:** an unattended weekly run in GitHub Actions; occasional manual runs from the Actions tab; a local dry run from the development machine.
**User mental model:** "untagged leftovers disappear after a week; anything with a tag, and anything a tag needs, stays."

**What this touches:** a new workflow under `.github/workflows/`; a new command `bin/ghcr-cleanup` and its logic in `lib/collector/ghcr_cleanup.rb` (`Collector::GhcrCleanup`, autoloaded with `lib/`, so the file loads without side effects; the command `require_relative`s it like `bin/dev-certificate`), with specs under `spec/lib/collector/`; `.dockerignore` and `bin/image-smoke` (keep the new files out of the public image); `docs/releasing.md` (document the cleanup). The publish workflow in `ci.yml` is not changed.

## User Stories

### Story 1: Orphans are deleted after the grace period

**As the** maintainer
**I want** untagged leftovers removed automatically
**So that** the package lists only what is published

**Acceptance criteria:**

- [ ] **AC-1.1** Given an untagged, single-architecture version that no tagged manifest list references, created more than 7 days ago When a deleting run happens Then that version is deleted.
- [ ] **AC-1.2** Given an untagged manifest list created more than 7 days ago whose two children are untagged and referenced by no tagged manifest list When a deleting run happens Then the list and both children are deleted in that run.
- [ ] **AC-1.3** Given an orphan unit whose children were created more than 7 days ago but whose manifest list was created less than 7 days ago When a deleting run happens Then none of the three is deleted.
- [ ] **AC-1.4** Given an untagged, unreferenced version created less than 7 days ago When a deleting run happens Then it is kept.
- [ ] **AC-1.5** Given the workflow file When it is read Then it runs on a weekly schedule as a deleting run and can be started by hand from the Actions tab.
- [ ] **AC-1.6** Given a deleting run has just finished When a second deleting run happens with no publish in between Then it deletes nothing and succeeds.

### Story 2: Tagged images never break

**As a** self-hoster
**I want** every tag I pull to keep working
**So that** the cleanup is invisible to me

**Acceptance criteria:**

- [ ] **AC-2.1** Given a tagged version of any age, including one with several tags When a deleting run happens Then it is kept.
- [ ] **AC-2.2** Given an untagged version created more than 7 days ago that a tagged manifest list references When a deleting run happens Then it is kept.
- [ ] **AC-2.3** Given an untagged manifest list older than 7 days that shares a child digest with a tagged manifest list When a deleting run happens Then the untagged list is deleted and the shared child is kept.
- [ ] **AC-2.4** Given a deleting run that deleted at least one version When it finishes deleting Then it checks that every tag still resolves to a manifest list with exactly `linux/amd64` and `linux/arm64` and that every child digest each list names is still fetchable from the registry; the run fails, naming the tag and the missing digest, if any is not.
- [ ] **AC-2.5** Given the first deleting run against the live package When it has finished Then an anonymous `podman pull` of `latest`, `0.1.0` and `edge` succeeds for both `linux/amd64` and `linux/arm64` (the maintainer's check, recorded in `verification.md`).

### Story 3: The cleanup fails closed

**As the** maintainer
**I want** the cleanup to stop rather than guess
**So that** an API change or a stray tag can't delete a published image

**Acceptance criteria:**

- [ ] **AC-3.1** Given the version list can't be read (an HTTP error, a refused token, or a response that is not a version list: a JSON array whose every element has an integer `id`, a `name` beginning `sha256:`, a parseable `created_at` and an array at `metadata.container.tags`) When any run happens Then nothing is deleted and the run exits non-zero with a message naming the failed request.
- [ ] **AC-3.2** Given a package with more versions than one page of the version list holds When any run happens Then every page is read before anything is selected, so a tagged version on a later page still protects its children.
- [ ] **AC-3.3** Given a tagged version whose manifest can't be fetched When any run happens Then nothing is deleted and the run exits non-zero naming that tag.
- [ ] **AC-3.4** Given a tagged version whose manifest is a single image (for example one tagged by a plain `bin/kamal deploy`) or has an unknown media type When any run happens Then nothing is deleted and the run exits non-zero naming that tag and its media type.
- [ ] **AC-3.5** Given an untagged version that is a candidate for deletion whose manifest can't be fetched or has an unknown media type When any run happens Then nothing is deleted and the run exits non-zero naming that digest.
- [ ] **AC-3.6** Given a deleting run in which GitHub refuses a delete with any status other than 404 (401, 403 including the 5,000-download limit on public versions, 5xx) When the refusal arrives Then no further version is deleted and the run exits non-zero naming the refused version and the response status.
- [ ] **AC-3.9** Given a deleting run in which a delete returns 404 When the response arrives Then the version is reported as already deleted and the run continues.
- [ ] **AC-3.7** Given neither `GH_TOKEN` nor `GITHUB_TOKEN` is set When `bin/ghcr-cleanup` starts Then it exits non-zero before any request, naming `GH_TOKEN`.
- [ ] **AC-3.8** Given a tagged manifest list whose platforms are not exactly `linux/amd64` and `linux/arm64` When any run happens Then nothing is deleted and the run exits non-zero naming the tag and the platforms it found.

### Story 4: Dry runs show what would happen

**As the** maintainer
**I want** to see what a run would delete before it does
**So that** I can check the rule against the real package

**Acceptance criteria:**

- [ ] **AC-4.1** Given `bin/ghcr-cleanup` is run without the delete flag When it finishes Then it deletes nothing and prints, for each version it would delete, the digest, its creation time, its tags (none) and why it is selected; and it prints the counts of versions in four disjoint buckets, assigned in this order: tagged, referenced (untagged), too young, selected; the four counts sum to the number of versions.
- [ ] **AC-4.2** Given the workflow is started by hand When its dry-run input is left at its default Then the run is a dry run, and the job doing it has no `packages: write` permission.
- [ ] **AC-4.3** Given the live package on the day of verification When a dry run is made from the development machine with the maintainer's `gh` token Then its selection is exactly the orphan units that are past the grace period, the orphan units inside it are reported as too young with their ages, and nothing is deleted. On 2026-10-08 the only orphan unit was `f03eb8274a90…` with its children `90ceeb5c0550…` and `0f9c9927048e…`: too young until 2026-10-15, selected after.

### Story 5: Documented, and kept out of the image

**As the** maintainer
**I want** the cleanup documented and the public image unchanged
**So that** I can run or pause it later without reading the code

**Acceptance criteria:**

- [ ] **AC-5.1** Given `docs/releasing.md` When it is read Then it has a section on the cleanup saying: what is deleted and what is never deleted, the 7-day grace period, the weekly schedule, how to start a run by hand (dry run by default), how to make a local dry run, and that a run that fails closed must be investigated before re-running.
- [ ] **AC-5.2** Given the built image When its filesystem is checked by `bin/image-smoke` Then `bin/ghcr-cleanup` and the cleanup's file under `lib/collector/` are absent, and the image still boots (spec 012 AC-6.2 unchanged).

## Functional Requirements

### FR-1: Selection

**Must:**
- Read every page of the package's version list before selecting anything.
- Read manifests from `https://ghcr.io/v2/plainprogrammer/collector/manifests/<digest>`, by the version's digest (never by tag), with one anonymous pull token per run from `https://ghcr.io/token?scope=repository:plainprogrammer/collector:pull`, sending `Accept` with all four list and single-image media types (GHCR answers 404 to a request whose `Accept` omits the manifest's type). Take the media type from the response `Content-Type`, falling back to the body's `mediaType`.
- Read the manifest of every tagged version, require a manifest list with exactly `linux/amd64` and `linux/arm64` (AC-3.4, AC-3.8), and treat its child digests as referenced, whether or not they are in the version list.
- Read the manifest of every candidate (untagged, unreferenced). A manifest list forms an orphan unit with its children as the Terms define; a single image is a unit on its own unless a list's unit already holds it; merge units that share a member.
- Select an orphan unit when it is past the grace period; select all its members together.
- Delete a unit's manifest list before its children, so an interrupted run leaves only standalone children, which a later run selects as their own units.

**Must not:**
- Select a tagged version.
- Select a referenced digest, whatever its age.
- Select part of an orphan unit.

### FR-2: Failing closed

**Must:**
- Delete nothing when the version list, a tagged version's manifest, or a candidate's manifest can't be read; when a tagged version is not a two-platform manifest list; or when a candidate has an unknown media type. Exit non-zero naming the version or request.
- Stop deleting at the first delete refused with a status other than 404; exit non-zero naming the version and the response status.
- Exit non-zero before any request when the token is missing.
- Set explicit timeouts on every request: 10 seconds to open, 30 seconds to read.

- Treat a 404 on delete as already deleted: report it and continue (AC-3.9).

**Must not:**
- Retry a failed delete within the same run.

### FR-3: Run modes

**Must:**
- Be a dry run unless the delete flag is given.
- Print, in both modes, each selected version with digest, creation time and reason, and the counts named in AC-4.1; in a deleting run, also print each deletion as it happens.
- Read the GitHub token from `GH_TOKEN`, falling back to `GITHUB_TOKEN`, so the same command runs locally (`GH_TOKEN="$(gh auth token)"`) and in the workflow.
- Read the package list from `https://api.github.com/users/plainprogrammer/packages/container/collector/versions?per_page=100&page=N`, starting at page 1 and incrementing until a page returns fewer than 100 entries; do not follow the `Link` header (it points at a `/user/{id}/…` path). Delete through `DELETE https://api.github.com/users/plainprogrammer/packages/container/collector/versions/{id}`. The workflow token acts as `github-actions[bot]`, so the `/user/packages/…` endpoints are not used.

### FR-4: Workflow

**Must:**
- Run on a weekly schedule, Sundays at 06:00 UTC, as a deleting run, and on `workflow_dispatch` with a boolean `dry_run` input defaulting to `true`.
- Have two jobs with exclusive conditions: `dry-run` (`if: github.event_name == 'workflow_dispatch' && inputs.dry_run`, permissions `contents: read`, `packages: read`) and `delete` (`if: github.event_name == 'schedule' || inputs.dry_run == false`, permissions `contents: read`, `packages: write`).
- Pass the token to the command as `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` on the step.
- Leave the post-delete check (AC-2.4) to the command; the workflow adds no check of its own.
- Use only actions already used in `ci.yml` or published by GitHub.

**Must not:**
- Run on pushes or pull requests.
- Change `ci.yml`.

### FR-5: Image and docs

**Must:**
- Exclude `bin/ghcr-cleanup` and the cleanup's file under `lib/collector/` from the image build context, and add both to `bin/image-smoke`'s absent-path check.
- Add the cleanup section to `docs/releasing.md` (AC-5.1).

## Non-Functional Requirements

- **Security:** no third-party code runs with `packages: write` (ADR 0011); the token is never printed, nor included in error messages that echo requests; the workflow token is the credential unless it is refused (Open Questions).
- **Reliability:** a run is idempotent (AC-1.6); deleting is safe to interrupt, because each orphan unit is untagged and unreferenced and its list goes first, so a partly deleted unit breaks no tag and its remaining children are standalone units for the next run (a 404 on one of them is treated as already deleted).
- **Testability:** the selection and fail-closed rules are tested without network access (WebMock blocks real HTTP), with fixtures shaped like the live package, including a version with several tags, a child shared with a tagged list, a child shared by two untagged lists of different ages, a child missing from the version list, more than one page of versions, an orphan unit straddling the grace period, a delete answering 404, and a post-delete check that finds a child missing. The workflow's triggers, jobs, conditions and permissions are checked as file-shape specs, as `spec/image_publishing_spec.rb` does for `ci.yml`.
- **Performance:** a run fetches one pull token, makes one list request per page, one manifest request per tagged version and per candidate, and one delete per selected version; it finishes within the job's default timeout for a package of a few hundred versions.
- **Portability:** stdlib only; no new gems.

## Error Scenarios

| Scenario | Expected behaviour |
|---|---|
| Version list returns 401/403/5xx or malformed JSON | Nothing deleted; exit non-zero naming the request (AC-3.1) |
| A tagged manifest returns 404/5xx | Nothing deleted; exit non-zero naming the tag (AC-3.3) |
| A tag points at a single-architecture image or unknown media type | Nothing deleted; exit non-zero naming the tag and media type (AC-3.4) |
| A tagged list has platforms other than exactly amd64 and arm64 | Nothing deleted; exit non-zero naming the tag and platforms (AC-3.8) |
| A candidate's manifest can't be read | Nothing deleted; exit non-zero naming the digest (AC-3.5) |
| A delete is refused (401, 403, the 5,000-download limit on public versions, 5xx) | Stop; exit non-zero naming the version and status; already-deleted orphans stay deleted (AC-3.6) |
| A delete returns 404 | Reported as already deleted; the run continues (AC-3.9) |
| Two release re-runs reuse one cached child | Both untagged lists and the child are one unit, deleted when its newest member is past the grace period |
| A publish is in progress during a run | Its untagged digests are minutes old, inside the grace period, so they are kept (AC-1.4) |
| A release re-run reuses a child digest | The child is referenced by the new tagged list and kept; the old list is deleted (AC-2.3) |
| Token missing | Exit non-zero before any request (AC-3.7) |
| A tag's child digest is no longer fetchable after deleting | The run fails naming the tag and digest (AC-2.4) |

## Open Questions

- **Can the workflow token delete package versions?** GitHub documents it for packages published by the same repository's workflow, which is this package's case. Verified during implementation with the first manual deleting run. If it is refused, the fallback (already accepted in the PRD) is a fine-grained token with `packages` read and write in a repository secret, and `docs/releasing.md` says how to rotate it. GitHub documents `GITHUB_TOKEN` package deletion as public preview and the `/users/…` list endpoint as being for public packages, so `docs/releasing.md` documents the fallback even if the first run succeeds.

## Out of Scope

- A retention policy for tagged images (how many `sha-*` tags or releases to keep).
- Cleanup of GitHub Actions caches or artifacts.
- Alerting beyond the failed workflow run's normal notification.
