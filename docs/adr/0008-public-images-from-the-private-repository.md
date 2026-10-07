# 0008: Publish public container images from the private repository

## Status

Accepted (2026-10-07)

**Date:** 2026-10-07
**Feature:** 012-ghcr-registry-publishing

## Context

Collector is meant to be easy to self-host (foundation principle 1). Today both deployment paths build the
`Dockerfile` themselves: `compose.yaml` has `build: .`, and Kamal pushes to a placeholder registry. A
self-hoster needs a checkout and a build toolchain before the first run, and an upgrade means pulling source and
rebuilding. Publishing a ready-made image removes that work.

The repository is private and will become public later. The images are planned to be public now. GitHub
Container Registry (GHCR) allows this, with constraints verified against GitHub's documentation on 2026-10-07:

- A package linked to a repository inherits the repository's access permissions but not its visibility, so a
  public package can be linked to a private repository. The first push from a workflow creates the package
  private; the owner changes it to public in the package settings.
- Once a package is public it cannot be made private again. The only way back is deleting the package.
- Artifact attestations (build provenance) are available to private repositories only on GitHub Enterprise
  Cloud. On the Free, Pro and Team plans they need a public repository.
- The Rails image copies the application into `/rails`, so anyone who can pull a public image can read the
  source. Collector is AGPL-3.0, so the source must be available to users anyway, but a public image publishes
  it before the repository does. The image today also contains `docs/`, `spikes/`, `spec/`, `.claude/` and
  research scripts, because `.dockerignore` does not exclude them.

The maintainer ruled on 2026-10-07 that the images go public before the repository does.

## Options considered

### Option A: Publish privately now, go public with the repository

**Pros:**
- The source stays private until the repository opens; attestations can be enabled at the same time.
- No image hygiene needed before anyone outside can pull.

**Cons:**
- Self-hosters other than the maintainer get nothing until the repository opens, so the main benefit is
  deferred for an unknown time.
- Pulling a private package needs a token on every self-hosting machine, which the README would have to
  explain and then unexplain.

### Option B: Publish publicly as soon as the flow works (chosen)

**Pros:**
- Anyone can pull `ghcr.io/plainprogrammer/collector` without credentials; `docker compose pull` just works.
- The publishing flow is exercised under real conditions early, before the repository opens.
- Matches the AGPL obligation to make the source available to everyone who runs the software.

**Cons:**
- The source is readable from the image before the repository is public. Accepted by the maintainer.
- Development-only files must be excluded from the image first, and the visibility flip is one-way.
- Build provenance attestations are not available until the repository is public.

### Option C: Publish to a different registry (Docker Hub)

**Pros:**
- Visibility is decoupled from the GitHub repository entirely.

**Cons:**
- A second account and token to manage; Docker Hub rate-limits anonymous pulls.
- GHCR is free for public images, authenticates from Actions with the workflow's own token, and sits beside the
  repository that self-hosters will eventually find.

## Decision

We chose Option B: publish public images to GHCR from the private repository, because the maintainer wants
self-hosters to pull a ready-made image now, and GHCR supports a public package on a private repository.

Three safeguards follow from the one-way flip and the source exposure:

1. `.dockerignore` excludes development-only paths before the first public push, so the image carries only what
   it runs (see the PRD's goals).
2. The visibility change is a manual, documented step in the release checklist, never performed by the
   workflow: push the first image, verify an authenticated pull, link the package to the repository, change the
   visibility, verify an anonymous pull.
3. Build provenance attestations are out of scope until the repository is public; the workflow is shaped so
   adding them later is one more job.

## Consequences

- Self-hosting no longer needs a checkout or a build; the Compose and Kamal paths consume the published image
  (PRD goals).
- Collector's source is effectively public from the first public image. Anything in the repository that must
  stay private has to be outside the image, not just outside Git's history.
- The package name `ghcr.io/plainprogrammer/collector` becomes a public contract (see
  [ADR 0009](0009-image-tags-and-release-channels.md) for the tags).
- When the repository becomes public, revisit: enable attestations, and note that Actions minutes for the
  builds become free.
