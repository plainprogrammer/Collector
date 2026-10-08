# 0009: Image tags and release channels

## Status

Accepted (2026-10-07)

**Date:** 2026-10-07
**Feature:** 012-ghcr-registry-publishing

## Context

The repository has no git tags and no version file; nothing names a release today. Once images are public
([ADR 0008](0008-public-images-from-the-private-repository.md)), their tags are what self-hosters pin to and what
the README's upgrade instructions name. Renaming or re-meaning a public tag later breaks running instances, so
the scheme has to be settled before the first public push.

Two kinds of consumer were discussed: self-hosters who want releases that upgrade in place (foundation
principle 1), and people who want to run ahead on the latest `main` to try a feature or report a bug. Pull
requests must be built to catch `Dockerfile` breakage, but must not publish anything. Kamal deploys by pulling
`<registry>/<image>:<version>`, so a release tag also has to be something `bin/kamal deploy --version` can name.

## Options considered

### Option A: Release tags plus a `main` channel (chosen)

A git tag `vX.Y.Z` publishes `X.Y.Z`, `X.Y`, `X` and `latest`; the major-only tag `X` starts at `1`, since
semantic versioning treats `0.y.z` as initial development and Docker's metadata action recommends not emitting a
bare `0`. A pre-release tag such as `v1.0.0-rc.1` publishes only `1.0.0-rc.1`. Every push to `main` publishes
`edge` and `sha-<short sha>`. Pull requests build and never push.

**Pros:**
- Semantic version tags let self-hosters choose how much they follow: a fixed patch, a minor line, or `latest`.
- `edge` gives early adopters a moving target that is clearly labelled as such; `sha-*` makes a report
  reproducible.
- `X.Y.Z` is exactly what `bin/kamal deploy --skip-push --version X.Y.Z` needs.

**Cons:**
- Every merge to `main` costs a two-architecture build on the private repository's Actions minutes.
- `sha-*` tags accumulate; cleanup is a separate concern.

### Option B: Release tags only

Only `vX.Y.Z` tags publish; `main` builds but pushes nothing.

**Pros:**
- Fewest published tags and the lowest Actions cost.

**Cons:**
- No way to run ahead of a release without building locally, which is the work the images are meant to remove.
- Bugs reported from `main` cannot name an image.

### Option C: GitHub Releases drive publishing

Publishing a GitHub Release triggers the push; release notes live on the release page.

**Pros:**
- A changelog and a download page come for free.

**Cons:**
- Adds release-notes authoring to every release, which was not asked for.
- The repository is private, so the release page is not visible to the image's public consumers yet.

## Decision

We chose Option A because the PRD wants both in-place upgrades for self-hosters and a way to run the latest
`main`, and because `X.Y.Z` tags double as Kamal versions. The first release is `v0.1.0`, publishing `0.1.0`,
`0.1` and `latest`. The workflow publishes on any tag push matching `vX.Y.Z` or `vX.Y.Z-<suffix>`; tagging an annotated tag on
`main` is release procedure in `docs/releasing.md`, not something the workflow checks.

Tag rules in full:

| Trigger | Tags published |
|---|---|
| Pull request | none (build only) |
| Push to `main` | `edge`, `sha-<short sha>` |
| Tag `vX.Y.Z` | `X.Y.Z`, `X.Y`, `latest`, and `X` when X ≥ 1 |
| Tag `vX.Y.Z-<pre>` | `X.Y.Z-<pre>` only |

Each image carries the OCI labels `org.opencontainers.image.source`, `.version`, `.revision`, `.licenses`
(`AGPL-3.0`) and `.description`, so the package page and `podman inspect` describe what was built.

## Consequences

- `latest` always means the newest stable release, never `main`; the README's Compose default pins `latest`.
  Nothing but the workflow may push to `ghcr.io/plainprogrammer/collector`: a plain `bin/kamal deploy` would
  push an `amd64`-only `latest`, so the maintainer deploys with `--skip-push --version X.Y.Z` and the README says
  so.
- A version is a git tag; there is no version file in the repository, and the app does not display its version
  (out of scope in the PRD).
- The private repository pays Actions minutes for every merge to `main`; when the cost matters, the `main`
  channel can be throttled without changing the release tags.
- Retention of `sha-*` images is a later decision; nothing depends on them staying.
