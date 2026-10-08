# 0011: Own script for GHCR untagged-version cleanup

## Status

Proposed

**Date:** 2026-10-08
**Feature:** 013-ghcr-untagged-cleanup

## Context

Every publish to `ghcr.io/plainprogrammer/collector` ([ADR 0010](0010-native-multi-architecture-image-builds.md))
pushes two per-architecture images by digest, untagged, and then a tagged manifest list that references them. A
re-run of a release retags a new manifest list and leaves the old list and its two children untagged and
unreferenced. On 2026-10-08 the package had 18 versions, 13 untagged: 10 of those are children of the five
tagged manifest lists and must stay, and only 3 (one orphaned list and its two children) are safe to delete.

So "delete untagged versions" is wrong as stated: a cleanup must know which digests a tagged manifest list still
references. The cleanup needs `packages: write` on the package the public pulls from, so whatever runs it can
delete or break every published image. Options were checked on 2026-10-08:

- `actions/delete-package-versions` (GitHub): deletes untagged versions with no knowledge of manifest lists, so
  it would delete the per-architecture children and break every tag.
- `dataaxiom/ghcr-cleanup-action`: built for GHCR and multi-architecture images (`delete-untagged`,
  `older-than`, `dry-run`, `validate`).
- `snok/container-retention-policy` v3: a retention action that also aims to keep multi-platform children; its
  handling would need checking before relying on it.
- A script in this repository using the GitHub packages API to list and delete versions and the registry API to
  read manifests.

## Options considered

### Option A: `dataaxiom/ghcr-cleanup-action`

**Pros:**
- Least code to write; designed for exactly this case, with a dry run and a post-delete validation.

**Cons:**
- Third-party code gets `packages: write` on the public image; pinning by commit SHA limits but doesn't
  remove that trust, and each Dependabot bump needs a review of what it now does.
- Its selection logic is not covered by our suite; a behaviour change shows up as broken pulls.

### Option B: `snok/container-retention-policy` v3

**Pros:**
- Small configuration, retention by age and tag patterns.

**Cons:**
- The same trust trade-off as Option A, and its multi-architecture handling is less certain.

### Option C: Own script, `bin/ghcr-cleanup` (chosen)

**Pros:**
- No third-party code holds delete rights on the public image; only GitHub's own actions run in the workflow.
- The selection logic is a plain Ruby class with RSpec examples run by `bin/ci`, so the rule that keeps
  referenced digests is tested before merge (Foundation principle 5).
- Stdlib only, like `Collector::DevPort`; it runs locally in dry-run mode against the real package.
- Can fail closed: if any tagged manifest cannot be read, it deletes nothing.

**Cons:**
- Around a hundred lines of code and specs to maintain.
- We own the correctness of the manifest parsing (OCI index and Docker manifest list media types).

## Decision

We chose Option C: a stdlib-only Ruby class under `lib/collector/` with a `bin/ghcr-cleanup` entry point, run
by a scheduled GitHub Actions workflow. The reason is that the cleanup can break every published image, so its
rule must be tested in our suite and must not depend on third-party code holding delete rights.

## Consequences

- A change to how images are published (attestations, provenance or SBOM entries in the manifest list, a third
  architecture) must keep the cleanup's notion of "referenced" correct; the specs are where that shows.
- If GitHub's packages API or GHCR's registry API changes shape, the script fails closed and the workflow run
  goes red rather than deleting the wrong thing.
- If maintaining the script outweighs the trust concern later, Option A is the drop-in replacement; a new ADR
  would supersede this one.
