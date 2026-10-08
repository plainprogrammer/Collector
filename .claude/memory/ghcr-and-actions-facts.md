---
name: ghcr-and-actions-facts
description: Verified GHCR, GitHub Actions, docker actions and Kamal facts from spec 012 — visibility one-way, attestations, arm64 runners, metadata-action v0, kamal config limits
metadata:
  type: reference
---

Facts verified while building spec 012 (2026-10-07/08):

- **GHCR visibility** is independent of the repository's: a public package can be linked to a private repo. The first push from a workflow creates it private; making it public cannot be undone (only deleting the package goes back). The `org.opencontainers.image.source` label links the package to the repo automatically.
- **Artifact attestations** need a public repository on the Free, Pro and Team plans (private repos only on Enterprise Cloud).
- **Native arm64 runners:** `ubuntu-24.04-arm` works in this private repo (2 vCPUs); an image build plus smoke test takes about 3 minutes.
- **`docker/build-push-action`** adds a provenance attestation by default when pushing, giving a manifest list four entries; `provenance: false` and `sbom: false` keep it at two.
- **`docker/metadata-action`:** skip a bare `0` tag for `0.y.z` with `type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}`; `type=sha` also fires on tag pushes unless gated to `main`.
- **Actions `permissions:`** accept no expressions, so a job that pushes on `main` also has `packages: write` on pull requests; gate the push steps with `if:` instead.
- **Tag filters** support `+` and `[0-9]` ranges, e.g. `v[0-9]+.[0-9]+.[0-9]+`.
- **Kamal 2.12.0:** `bin/kamal config` prints YAML with symbol keys (`:absolute_image:`), does not resolve secrets, and has no dry run; the registry validator requires `username` and `password` for any non-localhost registry, even to pull a public image; `deploy --skip-push --version X` pulls instead of building.

**How to apply:** check these before specifying or planning registry, CI or Kamal work. Related: [[spec-012-followups]].
