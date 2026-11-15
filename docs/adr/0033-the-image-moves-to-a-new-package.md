# 0033: The image moves to a new package, `ghcr.io/plainprogrammer/wyrmshoard`, with new releases only; the old package stays frozen

## Status

Accepted (2026-11-14; the maintainer, with the PRD of spec 092, after five read-only reviews). Written as Proposed. Written with the PRD of spec 092; the maintainer chose the option below in the brainstorm of 2026-11-14 ([#433](https://github.com/plainprogrammer/Collector/issues/433), [#434](https://github.com/plainprogrammer/Collector/issues/434)). It supersedes one consequence of [ADR 0008](0008-public-images-from-the-private-repository.md), and nothing else of it: that the package name `ghcr.io/plainprogrammer/collector` is a public contract. From release 0.4.0 the contract is the new name.

**Date:** 2026-11-14
**Feature:** 092-rename-to-wyrms-hoard

## Context

The application is renamed to Wyrm's Hoard and its repository to `plainprogrammer/wyrmshoard` ([ADR 0032](0032-the-rename-is-a-clean-break.md)). Its images are published at `ghcr.io/plainprogrammer/collector`: the releases 0.1.0, 0.2.0, 0.2.1 and 0.3.0 with their channel tags, and `edge` from `main` (ADR 0009).

Facts that bound the choice:

- GitHub redirects a renamed repository's URLs. A container package's name is not the repository's and is not redirected: a package under the new name is a new package, and pulls of the old name keep reading the old one.
- The image name is written in `ci.yml` (`IMAGE`), `compose.yaml`, `config/deploy.yml`, the cleanup script and its workflow (`lib/collector/ghcr_cleanup.rb`, `.github/workflows/ghcr-cleanup.yml`), the upgrade proof (`script/upgrade/harness.rb`, `REPOSITORY`) and the documentation.
- The upgrade proof boots the previous release's published image (spec 031). For release 0.4.0 the previous release is 0.3.0, which exists only under the old name.
- The first push to a new package name creates the package. A package's visibility is its own setting, so the new one has to be checked, and made public if it isn't, before anyone can pull it without credentials (ADR 0008 did this once for the old package). The repository is public now, so the new package may be public from its first push.
- The maintainer's is the only instance (ADR 0032, Context).

## Options considered

- **A. New releases only; the old package stays frozen (chosen).** Nothing is copied. The new package starts with `edge` from the first `main` build that names it, and its first release is 0.4.0. The old package is left as it is and nothing is pushed to it again. Costs: releases up to 0.3.0 can be pulled only by the old name, and the upgrade proof needs to know which package holds a given release.
- **B. Copy the release tags to the new package by digest, then delete the old package.** One package and one name in the proof, at the cost of a copy step that must be verified per tag and architecture, a delete that can't be undone, and images under the new name that call themselves Collector inside. Not chosen.
- **C. Copy the release tags and keep the old package.** As B without the delete; two packages hold the same images. Not chosen.

## Decision

1. **The image is `ghcr.io/plainprogrammer/wyrmshoard`** from the first build of `main` that names the new image. Everything that names the image names the new one.
2. **No existing image is copied, rebuilt or retagged.** The new package's first release is 0.4.0.
3. **The old package, `ghcr.io/plainprogrammer/collector`, is frozen:** nothing pushes to it, nothing deletes from it, and the weekly cleanup works on the new package only. Its `latest` stays 0.3.0 and its `edge` stays the last build before the rename.
4. **The upgrade proof pulls a release of 0.3.0 or earlier from the old package and any later release from the new one.** The rule is written once, beside the proof's repository constant and its `UPGRADE_IMAGE_REPOSITORY` override, with this ADR as its source.
5. **The new package is public before 0.4.0 is tagged.** Checking it is a step of the release: an anonymous pull, and if that fails the maintainer makes the package public in its settings.

## Consequences

- **Good:** the rename needs no registry operation beyond the builds CI already does, and nothing irreversible happens to published images.
- **Good:** the old package keeps answering the pull commands in release 0.3.0's own documentation.
- **Cost:** the upgrade proof carries a rule about two packages for as long as it can be asked to start from 0.3.0 or earlier; it is the one place in the code that still names the old image.
- **Cost:** an operator on the old image who follows `latest` stays on 0.3.0 with no notice. Accepted: the only operator is the maintainer (ADR 0032).
- **Limit:** the old package's untagged versions are no longer cleaned up. Their number can't grow, since nothing pushes there.
- **Follow-up:** deleting the old package later is a separate decision; when it is taken, decision 4 goes with it.
- **Follow-up:** ADR 0008's note to revisit attestations once the repository is public is unchanged by this ADR.
