---
date: 2026-10-08
spec: "012"
tags: [ci, github-actions, docker, spec-writing]
---

# Lesson: Read the build tools' mechanics before writing CI and registry criteria

## Context

Spec 012 specified a GitHub Actions flow that builds per-architecture images, pushes them by digest, and publishes one tagged manifest list to GHCR.

## What happened

The Mode A spec review found four criteria that were unachievable as written:

- **"Nothing is pushed" on failure was false.** Push-by-digest pushes each architecture's image, untagged, before the merge job; if one architecture fails, the other's digest is already there.
- **The manifest list would have four entries.** `docker/build-push-action` adds a provenance attestation by default, doubling the "exactly two entries" the spec required.
- **"Same content" on a re-run was impossible.** A rebuild is never byte-identical.
- **"Read-only on pull requests" couldn't be expressed.** Job `permissions:` accept no expressions, so a job that pushes on `main` has write access on pull requests too.

All four needed spec version 1.1.0 rewording before planning could start.

## What to do next time

For CI or registry features, read the build tool's defaults (attestations, push modes, cache targets) and the workflow-syntax limits before writing acceptance criteria. Phrase outcomes as what is published (tags, visibility, platforms), and say explicitly what may remain (untagged digests) instead of "nothing happens".

## Signals to watch for

- Criteria that say "nothing is pushed", "same content" or "only on X events".
- Criteria with exact counts of registry objects.
