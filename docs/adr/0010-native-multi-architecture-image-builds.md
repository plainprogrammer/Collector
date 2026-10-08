# 0010: Native multi-architecture image builds

## Status

Accepted (2026-10-07)

**Date:** 2026-10-07
**Feature:** 012-ghcr-registry-publishing

## Context

The published image must run on `linux/amd64` (x86 servers) and `linux/arm64` (Raspberry Pi 4 and 5, Apple
Silicon machines running Docker or Podman in a VM). The `Dockerfile` already carries a workaround for a QEMU
bug: bootsnap precompiles with `-j 1` because parallel compilation fails under emulation. Multi-architecture
builds in GitHub Actions can be done three ways, checked on 2026-10-07:

- QEMU emulation on one `ubuntu-latest` runner, the pattern in Docker's single-runner example. Emulated
  arm64 builds of a Rails image with native gems are several times slower than native and are where the
  bootsnap bug lives.
- Native runners per architecture: GitHub's `ubuntu-24.04-arm` label works in private repositories since
  January 2026 (two vCPUs there, four in public repositories), billed from the plan's minutes. Each runner builds
  one platform and pushes it by digest; a final job merges the digests into one manifest list with
  `docker buildx imagetools create`, using tags from `docker/metadata-action`. This is Docker's documented
  "distribute across runners" pattern.
- Docker's `github-builder` reusable workflow (v1), which implements the distribute-and-merge pattern itself and
  adds signed provenance and an optional SBOM. Its documentation has no GHCR login example, and using it means
  pinning a third-party workflow that receives `packages: write`.

Kamal's own builder was also considered: `bin/kamal build push` uses buildx with QEMU for a second
architecture, tags only the git SHA plus `latest`, and needs the registry token in `.kamal/secrets`.

## Options considered

### Option A: One runner, QEMU for arm64

**Pros:**
- One job, the shortest workflow.

**Cons:**
- The arm64 half of every build runs emulated; builds take much longer and keep the bootsnap workaround load-
  bearing.
- A single job cannot be parallelised.

### Option B: Native runners per architecture, merged manifest (chosen)

**Pros:**
- Both halves build at native speed in parallel; the QEMU workaround stops mattering in CI.
- Only Docker's official actions (`setup-buildx-action`, `login-action`, `metadata-action`,
  `build-push-action`) and a documented pattern; every step is visible in `ci.yml`.
- Pull requests can run the same matrix without pushing.

**Cons:**
- Three jobs instead of one, about sixty lines of YAML to maintain.
- Two runners per build on the private repository's minutes, and the arm64 runner there has two vCPUs.

### Option C: Docker's `github-builder` reusable workflow

**Pros:**
- Distribute-and-merge, provenance and SBOM with little YAML.

**Cons:**
- New at v1 with no documented GHCR path; failures are inside a workflow we do not own.
- Grants a third-party workflow write access to the public package.
- Its provenance features overlap with the attestations deferred by
  [ADR 0008](0008-public-images-from-the-private-repository.md), which we want to add deliberately later.

### Option D: Kamal builds and pushes from CI

**Pros:**
- Reuses `config/deploy.yml`.

**Cons:**
- QEMU for the second architecture, SHA-only tags that cannot express
  [ADR 0009](0009-image-tags-and-release-channels.md), and registry secrets in `.kamal/secrets` for a build that
  has nothing to do with deploying.

## Decision

We chose Option B: a matrix job builds `linux/amd64` on `ubuntu-latest` and `linux/arm64` on
`ubuntu-24.04-arm`, each pushing by digest, and a merge job publishes one manifest list with the tags from ADR
0009. The reason is speed and transparency: native builds avoid the emulation the `Dockerfile` already has to
work around, and the whole flow is in the repository using Docker's official actions.

The build runs in the existing `ci.yml` after the `ci` job, so an image is only published when `bin/ci` has
passed on that commit.

## Consequences

- Every pull request builds both architectures, so a `Dockerfile` regression is caught before merge, at the cost
  of two extra runners per pull request on the private repository.
- The `-j 1` bootsnap workaround in the `Dockerfile` stays: CI no longer needs it, but self-hosters building
  locally under emulation (an Apple Silicon machine building `amd64`, or the QEMU fallback below) still do.
- Adding attestations later is one more job after the merge, which is why the merge job and the per-platform
  builds are separate.
- If GitHub withdraws arm64 runners from private repositories, the matrix entry falls back to QEMU on
  `ubuntu-latest` without changing the tags or the merge job.
