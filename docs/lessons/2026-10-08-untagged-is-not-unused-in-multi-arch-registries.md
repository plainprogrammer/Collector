---
date: 2026-10-08
spec: "013"
tags: [ci, ghcr, registry, spec-writing]
---

# Lesson: In a multi-architecture registry, "untagged" is not "unused"

## Context

Issue #17 asked for a scheduled job deleting untagged versions of `ghcr.io/plainprogrammer/collector`, keeping every digest a tagged manifest list references.

## What happened

- **The obvious tool would have broken every tag.** Each tagged manifest list points to two per-architecture images that are themselves untagged: 10 of the 13 untagged versions on 2026-10-08. `actions/delete-package-versions` deletes untagged versions without reading manifest lists. Only 3 versions (one orphaned list and its images) were safe to delete.
- **The first post-delete check could not detect the failure it guarded against.** The spec said "check every tag still resolves to amd64 and arm64". Deleting a child image leaves its index intact, so that check (and `ci.yml`'s own platform check) still passes. The Mode A review caught it; the check now `HEAD`s every child digest.
- **Registry reads failed silently in a fail-closed design.** GHCR answers 404 unless `Accept` names the manifest's media type, so a cleanup that "fails closed on an unreadable manifest" would have failed on every run and never deleted anything. This was also caught only in review, by running requests against the live registry.

## What to do next time

Before specifying anything that deletes or verifies registry content, list what references what: manifest lists → child digests, and which of those carry tags. Write post-change checks against the thing that can disappear (the child), not the thing that stays (the index). Probe the live registry's request semantics (`Accept`, auth, paging) with read-only requests while writing the spec, not after.

## Signals to watch for

- "Delete untagged …" in a multi-architecture or attestation-bearing repository.
- A verification step that reads only the object the change does not touch.
