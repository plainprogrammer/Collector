# PRD: Build and publish Collector images to GHCR

**Date:** 2026-10-07
**Feature:** 012-ghcr-registry-publishing

## Problem

Collector is meant to be easy to self-host, but both supported paths make the self-hoster build the image:
`compose.yaml` builds from a checkout and Kamal builds and pushes to a registry the self-hoster must provide. A
first run needs the source, a container build toolchain and a download of the OCR engine; an upgrade means
pulling source and rebuilding. Nothing in the repository names a release, so there is no version a self-hoster
can pin to or report a bug against.

The maintainer wants ready-made, public, multi-architecture images published from CI so that running Collector
is a `docker compose pull`. The repository is private and will open later; the images go public first.

## Users & Context

- **Self-hosters** running Collector on an x86 server, a Raspberry Pi, or an Apple Silicon machine with Docker or
  Podman. They want to start from an image and upgrade in place with a documented command.
- **Early adopters** who want to run the latest `main` and report what they find with a reproducible image name.
- **The maintainer**, who cuts releases by tagging and deploys with Kamal, and who performs the one-time
  visibility change on the package.

This touches `.github/workflows/ci.yml` (today it only runs `bin/ci`), the `Dockerfile` and `.dockerignore`
(which currently copies the whole repository into the image, including `docs/`, `spikes/`, `spec/` and
`.claude/`), `compose.yaml`, `config/deploy.yml`, and the README's deployment sections, which must stay in sync
for both paths. The image is built from the existing `Dockerfile`, which fetches the pinned OCR engine during the
build. The repository currently has no git tags.

## Goals

- Publish `ghcr.io/plainprogrammer/collector` as a public image that runs on `linux/amd64` and `linux/arm64`.
- Publish from the existing CI workflow (which must also run on `v*` tag pushes), only after `bin/ci` has
  passed on the same commit: pull requests build
  both architectures without pushing; pushes to `main` publish the `edge` channel; `vX.Y.Z` tags publish
  release tags and `latest` (rules in ADR 0009). The workflow publishes on any tag push matching the release pattern.
- Keep development-only paths out of the image before the first public push: `docs/`, `spikes/`, `spec/`,
  `.claude/`, `CLAUDE.md`, `.githooks/`, `orca.yaml`, `.worktreeinclude`, and `script/`. The image must still
  boot, migrate on start, serve the scanner pages and OCR assets, and run the operational rake tasks
  (`catalog:*`, `collector:user`). The scanner findings tasks (`scanner:*`) are development-only research tools
  that read `spec/fixtures/card_scanner` and the maintainer's corpus; they are not expected to work in the image.
- Make the published image the default for self-hosting: `compose.yaml` pulls
  `ghcr.io/plainprogrammer/collector:latest` by default, overridable with `COLLECTOR_IMAGE` (which is also how a
  locally built image is used); the Kamal deploy file points at `ghcr.io/plainprogrammer/collector` and the
  README documents deploying a release with `bin/kamal deploy --skip-push --version X.Y.Z`. A self-hoster who
  wants Kamal to build their own image changes `image` and `registry` to a registry they own first. A plain
  `bin/kamal deploy` against the public image would push an `amd64`-only `latest` over the published one, so
  the README says never to run it against `ghcr.io/plainprogrammer/collector`.
- Label each image with OCI metadata (source, version, revision, licence `AGPL-3.0`, description).
- Document releasing in `docs/releasing.md`: how to cut a release (annotated `vX.Y.Z` tag on `main`, first
  release `v0.1.0`), what each trigger publishes, and the one-time go-public checklist (push the first image,
  verify an authenticated pull, link the package to the repository, change its visibility to public, verify an
  anonymous pull). The visibility change is manual because it cannot be undone. "Annotated, on `main`" is
  release procedure recorded there; the workflow publishes on any tag push matching the release pattern.
- Update the README's Docker Compose and Kamal sections together: first run from the image, upgrade with
  `docker compose pull && docker compose up -d`, and the build-from-source alternative.

## Non-Goals

- Build provenance attestations or SBOMs. They need a public repository on the current plan; the workflow
  leaves room for one more job later.
- Automating the package's visibility change.
- Retention or cleanup of `sha-*` images on GHCR.
- GitHub Releases, release notes, or changelog generation.
- Displaying the running version inside the app, or a version file in the repository.
- Dependabot updates for the Docker base image.
- A development or test image; the image is the production `Dockerfile` only.

## Success Criteria

- A pull request's CI run builds the image for both architectures and pushes nothing to GHCR.
- Pushing the tag `v0.1.0` produces, after `bin/ci` passes, one manifest list at
  `ghcr.io/plainprogrammer/collector` whose tags are `0.1.0`, `0.1` and `latest` (no bare `0`: the major-only
  tag starts at `1`), and `podman manifest inspect` shows both `linux/amd64` and `linux/arm64`.
- A push to `main` produces `edge` and `sha-<short sha>`.
- From a machine with no GHCR credentials, `podman pull ghcr.io/plainprogrammer/collector:latest` succeeds.
- `podman compose up -d` with the default `compose.yaml` and a `SECRET_KEY_BASE` boots the pulled image and
  `/up` reports healthy; `COLLECTOR_IMAGE=collector:local` runs a locally built image the same way.
- The pulled image contains none of the paths named in Goals (`docs/`, `spikes/`, `spec/`, `.claude/`,
  `CLAUDE.md`, `.githooks/`, `orca.yaml`, `.worktreeinclude`, `script/`); in it, the scanner pages and OCR
  assets load and `bin/rails "catalog:status[mtg]"` and `collector:user` run.
- `bin/kamal config` validates the updated `config/deploy.yml`.
- The README's Compose and Kamal sections describe the image-based first run and upgrade, and the build-from-
  source alternative, and `docs/releasing.md` exists with the release and go-public steps.

## Architecture Decisions

- [Publish public images from the private repository](../../adr/0008-public-images-from-the-private-repository.md)
  — images are public on GHCR before the repository is, with image hygiene first, a manual one-way visibility
  flip, and attestations deferred.
- [Image tags and release channels](../../adr/0009-image-tags-and-release-channels.md) — `vX.Y.Z` tags publish
  `X.Y.Z`, `X.Y`, `X` (from `1` up) and `latest`; `main` publishes `edge` and `sha-*`; pull requests build only.
- [Native multi-architecture image builds](../../adr/0010-native-multi-architecture-image-builds.md) — a matrix
  of native `amd64` and `arm64` runners pushing by digest, merged into one manifest in `ci.yml` after `bin/ci`.

Decided inline, without an ADR: the publish jobs live in the existing `ci.yml` rather than a second workflow
(so the `bin/ci` gate is a job dependency); the workflow authenticates to GHCR with its own `GITHUB_TOKEN`
(`packages: write`); Compose uses `image:` only, with `COLLECTOR_IMAGE` for overrides; Kamal keeps its registry
username set and the `KAMAL_REGISTRY_PASSWORD` entry uncommented, because Kamal requires both for any
non-local registry even when the image is public.

## Out of Scope

- Making the repository public, and everything that follows from it (attestations, free Actions minutes,
  linking the README on the package page).
- Changing the `Dockerfile`'s runtime (Thruster, non-root user, `db:prepare` on boot) or its OCR engine fetch.
- A second registry (Docker Hub) or mirror.
- Throttling the `main` channel to save Actions minutes; it can be done later without changing release tags.
