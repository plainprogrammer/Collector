# Feature 013: Clean Up Untagged GHCR Package Versions

**Status:** Approved
**Version:** 1.0.0
**Created:** 2026-10-08
**Last Updated:** 2026-10-08
**Branch:** `013-ghcr-untagged-cleanup`
**Issue:** [#17](https://github.com/plainprogrammer/Collector/issues/17)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-08 | Initial draft from the approved [prd.md](prd.md) and ADR [0011](../../adr/0011-own-ghcr-cleanup-script.md) |

---

## Problem Statement

Every publish to `ghcr.io/plainprogrammer/collector` (spec 012) pushes two per-architecture images untagged, by digest, and then a tagged manifest list that references them. A re-run of a release leaves the previous manifest list untagged. Nothing removes orphaned versions, so they accumulate: on 2026-10-08 the package had 18 versions, 13 untagged.

Most untagged versions are not garbage. Ten of those 13 are the per-architecture children of the five tagged manifest lists; deleting them breaks those tags for every self-hoster. Only three (one manifest list orphaned by a release re-run, and its two children) are safe to delete. This feature removes orphans on a schedule without ever breaking a tag.

> **Inputs.** Scope and decisions come from the approved [prd.md](prd.md) and the accepted [ADR 0011](../../adr/0011-own-ghcr-cleanup-script.md) (a cleanup script in this repository, stdlib-only, rather than a third-party action). The registry (GHCR), its package API (GitHub's REST packages API), the scheduler (GitHub Actions) and the publish flow of spec 012 / ADR 0010 are fixed inputs, so this spec names them. The command name `bin/ghcr-cleanup` is user-facing and is named here too.
>
> **Terms.**
> - A *version* is one entry in the package's version list: a digest, a creation time, and zero or more tags.
> - A version is *tagged* when the packages API reports at least one tag for it (`metadata.container.tags` non-empty). One version can carry several tags (the release list carries `latest`, `0.1` and `0.1.0`).
> - A *manifest list* is a version whose manifest is an OCI image index or a Docker manifest list; its *children* are the digests it references.
> - A digest is *referenced* when a tagged manifest list names it as a child.
> - An *orphan unit* is an untagged manifest list together with those of its children that are untagged and not referenced; any other untagged, unreferenced version is an orphan unit on its own. A unit's *age* is the age of its newest member.
> - The *grace period* is 7 days.
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

**What this touches:** a new workflow under `.github/workflows/`; a new command `bin/ghcr-cleanup` and its logic under `lib/collector/`, with specs under `spec/lib/collector/`; `.dockerignore` and `bin/image-smoke` (keep the new files out of the public image); `docs/releasing.md` (document the cleanup). The publish workflow in `ci.yml` is not changed.

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
- [ ] **AC-2.4** Given a deleting run that deleted at least one version When it finishes deleting Then it checks every remaining tag resolves to a manifest list with exactly `linux/amd64` and `linux/arm64`, and the run fails, naming the tag, if any does not.
- [ ] **AC-2.5** Given the first deleting run against the live package When it has finished Then an anonymous `podman pull` of `latest`, `0.1.0` and `edge` succeeds for both `linux/amd64` and `linux/arm64` (the maintainer's check, recorded in `verification.md`).

### Story 3: The cleanup fails closed

**As the** maintainer
**I want** the cleanup to stop rather than guess
**So that** an API change or a stray tag can't delete a published image

**Acceptance criteria:**

- [ ] **AC-3.1** Given the version list can't be read (an HTTP error, a refused token, or a response that is not a version list) When any run happens Then nothing is deleted and the run exits non-zero with a message naming the failed request.
- [ ] **AC-3.2** Given a package with more versions than one page of the version list holds When any run happens Then every page is read before anything is selected, so a tagged version on a later page still protects its children.
- [ ] **AC-3.3** Given a tagged version whose manifest can't be fetched When any run happens Then nothing is deleted and the run exits non-zero naming that tag.
- [ ] **AC-3.4** Given a tagged version whose manifest is not a manifest list (for example a single-architecture image tagged by a plain `bin/kamal deploy`) or has a media type the cleanup doesn't know When any run happens Then nothing is deleted and the run exits non-zero naming that tag and its media type.
- [ ] **AC-3.5** Given an untagged version that is a candidate for deletion whose manifest can't be fetched or understood When any run happens Then nothing is deleted and the run exits non-zero naming that digest.
- [ ] **AC-3.6** Given a deleting run in which GitHub refuses a delete When the refusal arrives Then no further version is deleted and the run exits non-zero naming the refused version and the response status.
- [ ] **AC-3.7** Given no token in the environment When `bin/ghcr-cleanup` starts Then it exits non-zero before any request, saying which environment variable it needs.

### Story 4: Dry runs show what would happen

**As the** maintainer
**I want** to see what a run would delete before it does
**So that** I can check the rule against the real package

**Acceptance criteria:**

- [ ] **AC-4.1** Given `bin/ghcr-cleanup` is run without the delete flag When it finishes Then it deletes nothing and prints, for each version it would delete, the digest, its creation time, its tags (none) and why it is selected; and it prints the counts of tagged, referenced, too-young and selected versions.
- [ ] **AC-4.2** Given the workflow is started by hand When its dry-run input is left at its default Then the run is a dry run, and the job doing it has no `packages: write` permission.
- [ ] **AC-4.3** Given the live package on the day of verification When a dry run is made from the development machine with the maintainer's `gh` token Then its selection is exactly the orphan units that are past the grace period (on 2026-10-08 those would have been `f03eb8274a90…` and its children `90ceeb5c0550…` and `0f9c9927048e…`, once 7 days old), and nothing is deleted.

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
- Read the manifest of every tagged version and collect the child digests of each; treat those digests as referenced.
- Read the manifest of every untagged version that is a candidate (untagged, unreferenced) to learn whether it is a manifest list, and if so group it with its untagged, unreferenced children into one orphan unit.
- Select an orphan unit when its newest member is older than 7 days at the time of the run; select all its members together.

**Must not:**
- Select a tagged version.
- Select a referenced digest, whatever its age.
- Select part of an orphan unit.

### FR-2: Failing closed

**Must:**
- Delete nothing when the version list, a tagged version's manifest, or a candidate's manifest can't be read, or a tagged version's manifest is not a manifest list of a known media type; exit non-zero naming the version or request.
- Stop deleting at the first refused delete; exit non-zero naming the version and the response status.
- Exit non-zero before any request when the token is missing.
- Set explicit open and read timeouts on every request.

**Must not:**
- Retry a failed delete within the same run.

### FR-3: Run modes

**Must:**
- Be a dry run unless the delete flag is given.
- Print, in both modes, each selected version with digest, creation time and reason, and the counts named in AC-4.1; in a deleting run, also print each deletion as it happens.
- Read the GitHub token from the environment, so the same command runs locally (`GH_TOKEN="$(gh auth token)"`) and in the workflow.
- Read the package list from `/users/plainprogrammer/packages/container/collector/versions` and delete through `DELETE …/versions/{id}`, because the workflow token acts as `github-actions[bot]` and can't use the `/user/packages/…` endpoints.

### FR-4: Workflow

**Must:**
- Run weekly on a schedule as a deleting run, and on `workflow_dispatch` with a dry-run input defaulting to on.
- Grant `packages: write` only to the job that deletes; a dry run gets `packages: read` at most; `contents: read` otherwise.
- After a deleting run that deleted anything, check every remaining tag as AC-2.4 states.
- Use only actions already used in `ci.yml` or published by GitHub.

**Must not:**
- Run on pushes or pull requests.
- Change `ci.yml`.

### FR-5: Image and docs

**Must:**
- Exclude `bin/ghcr-cleanup` and the cleanup's file under `lib/collector/` from the image build context, and add both to `bin/image-smoke`'s absent-path check.
- Add the cleanup section to `docs/releasing.md` (AC-5.1).

## Non-Functional Requirements

- **Security:** no third-party code runs with `packages: write` (ADR 0011); the token is never printed; the workflow token is the credential unless it is refused (Open Questions).
- **Reliability:** a run is idempotent (AC-1.6); deleting is safe to interrupt, because each orphan unit is untagged and unreferenced, so a partly deleted unit breaks no tag and is finished by the next run.
- **Testability:** the selection and fail-closed rules are tested without network access (WebMock blocks real HTTP), with fixtures shaped like the live package, including a version with several tags, a shared child, more than one page of versions, and an orphan unit straddling the grace period.
- **Performance:** a run makes one list request per page, one manifest request per tagged version and per candidate, and one delete per selected version; it finishes within the job's default timeout for a package of a few hundred versions.
- **Portability:** stdlib only; no new gems.

## Error Scenarios

| Scenario | Expected behaviour |
|---|---|
| Version list returns 401/403/5xx or malformed JSON | Nothing deleted; exit non-zero naming the request (AC-3.1) |
| A tagged manifest returns 404/5xx | Nothing deleted; exit non-zero naming the tag (AC-3.3) |
| A tag points at a single-architecture image or unknown media type | Nothing deleted; exit non-zero naming the tag and media type (AC-3.4) |
| A candidate's manifest can't be read | Nothing deleted; exit non-zero naming the digest (AC-3.5) |
| A delete is refused (403, 404, the 5,000-download limit on public versions) | Stop; exit non-zero naming the version and status; already-deleted orphans stay deleted (AC-3.6) |
| A publish is in progress during a run | Its untagged digests are minutes old, inside the grace period, so they are kept (AC-1.4) |
| A release re-run reuses a child digest | The child is referenced by the new tagged list and kept; the old list is deleted (AC-2.3) |
| Token missing | Exit non-zero before any request (AC-3.7) |
| A tag stops resolving to both architectures after deleting | The run fails naming the tag (AC-2.4) |

## Open Questions

- **Can the workflow token delete package versions?** GitHub documents it for packages published by the same repository's workflow, which is this package's case. Verified during implementation with the first manual deleting run. If it is refused, the fallback (already accepted in the PRD) is a fine-grained token with `packages` read and write in a repository secret, and `docs/releasing.md` says how to rotate it.

## Out of Scope

- A retention policy for tagged images (how many `sha-*` tags or releases to keep).
- Cleanup of GitHub Actions caches or artifacts.
- Alerting beyond the failed workflow run's normal notification.
