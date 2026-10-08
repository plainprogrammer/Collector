# PRD: Clean up untagged GHCR package versions

**Date:** 2026-10-08
**Feature:** 013-ghcr-untagged-cleanup
**Issue:** [#17](https://github.com/plainprogrammer/Collector/issues/17)

## Problem

Every publish to `ghcr.io/plainprogrammer/collector` (spec 012) pushes two per-architecture images untagged, by
digest, and then a tagged manifest list that references them. A re-run of a release orphans a whole manifest
list and its two children. Nothing ever removes orphans, so they accumulate: on 2026-10-08 the package had 18
versions, 13 of them untagged, after one day of publishing.

The untagged versions are not all garbage. Ten of those 13 are the children of the five tagged manifest lists
(`latest`/`0.1`/`0.1.0`, `edge`, and three `sha-*`); deleting them breaks those tags for every self-hoster.
Only three (one orphaned manifest list from a release re-run and its two children) are safe to delete. A naive
"delete untagged" job would break every published image.

## Users & Context

- **The maintainer**, who looks at the package page to see what is published and wants it to show only what
  matters.
- **Self-hosters**, who pull `latest`, `X.Y.Z`, `edge` or `sha-*` and must never notice the cleanup.

This touches a new workflow under `.github/workflows/`, a new class under `lib/collector/` with a `bin/` entry
point and specs under `spec/lib/collector/`, `.dockerignore` (keep the script out of the image), and
`docs/releasing.md` (how the cleanup runs and how to run it by hand). The publish workflow in `ci.yml` is not
changed. Release facts from spec 012 that bear on this are in `docs/releasing.md` and ADRs 0008–0010.

## Goals

- Delete package versions that are untagged, not referenced by any tagged manifest list, and older than 7 days.
- Treat an untagged manifest list and the children only it references as one orphan to delete together.
- Never delete a digest that a tagged manifest list references, and never delete a tagged version.
- Fail closed: if the version list or any tagged manifest cannot be read or understood, delete nothing and fail
  the run.
- Default to a dry run that prints what would be deleted and why; deleting needs an explicit flag.
- Run weekly on a schedule and on demand (`workflow_dispatch`, dry run selectable); the deleting job is the only
  one with `packages: write`.
- After deleting, check that every remaining tag still resolves to exactly `linux/amd64` and `linux/arm64`.
- Keep the selection rule in a plain, stdlib-only Ruby class covered by RSpec and run by `bin/ci`.

## Non-Goals

- Pruning tagged versions, including old `sha-*` tags or old releases.
- Changing how `ci.yml` builds, tags or publishes images.
- Cleaning up any package other than `ghcr.io/plainprogrammer/collector`.
- Adding attestations, provenance or SBOM entries (deferred by ADR 0008).

## Success Criteria

- After the first deleting run, the package holds no untagged version older than 7 days that no tagged manifest
  list references, and untagged versions stop accumulating beyond about two weeks of orphans.
- Every tag that existed before the run (`latest`, `0.1`, `0.1.0`, `edge`, every `sha-*`) still pulls for both
  `linux/amd64` and `linux/arm64`, checked by the workflow and once by hand with an anonymous pull.
- The specs prove that referenced children are kept, orphaned lists are deleted with their children, versions
  younger than 7 days are kept, and an unreadable manifest deletes nothing.
- A manual dry run against the live package lists exactly the expected orphans (on 2026-10-08:
  `f03eb827…` and its children `90ceebd5…` and `0f9c9927…`, once older than 7 days) and deletes nothing.

## Architecture Decisions

- [0011: Own script for GHCR untagged-version cleanup](../../adr/0011-own-ghcr-cleanup-script.md) — a
  stdlib-only Ruby class and `bin/ghcr-cleanup` instead of a third-party action, so no third-party code holds
  delete rights on the public image and the keep-referenced rule is tested in our suite.

Inline decisions (defaults, not ADR-level):

- **Age and schedule:** 7 days, weekly, plus `workflow_dispatch`. The age also protects a publish in progress,
  whose per-architecture digests are pushed untagged minutes before the manifest list.
- **Credentials:** the workflow's `GITHUB_TOKEN` with `packages: write`, if the repository has admin access on
  the package (packages created by a workflow normally grant it). If deletion is refused, a fine-grained token in
  a repository secret is the fallback; that is checked during implementation.
- **Manifests:** read from the registry API (`ghcr.io/v2/…`) with a pull token, accepting OCI image index and
  Docker manifest list media types; anything else under a tag fails closed.

## Out of Scope

- A retention policy for tagged images (how many `sha-*` or releases to keep): a separate decision if the tag
  count becomes a problem.
- Cleanup of GitHub Actions caches or artifacts.
