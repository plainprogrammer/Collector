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
- **CI triggers:** `.github/workflows/ci.yml` runs on pull requests, pushes to `main` and release tags only. Pushing a branch runs nothing; open a draft PR to exercise CI. Pull requests build and smoke-test both images (amd64, arm64; about 40 s each from cache) without publishing (verified on PR #24, 2026-10-08).
- **`.dockerignore`** keeps `/script`, `/spec`, `/docs`, `/spikes`, `/.claude` and `/.github` out of the image. A check that runs repository files inside the image must mount them, e.g. `-v "$PWD/script/scanner:/rails/script/scanner:ro"`.

Verified while building spec 013 (2026-10-08):

- **Tokens:** GitHub Packages accepts only classic personal access tokens, not fine-grained ones; deleting needs `read:packages` and `delete:packages`. `GITHUB_TOKEN` deletion of a package the repo's workflow published is documented as public preview (live check owed, see [[spec-012-followups]]).
- **Packages API:** `GITHUB_TOKEN` acts as `github-actions[bot]`, so use `/users/plainprogrammer/packages/container/collector/versions`, not `/user/packages/…`. Its `Link: rel="next"` points at `/user/{id}/…`; page with `?per_page=100&page=N` until a short page instead. The API needs auth even for a public package.
- **Registry reads:** an anonymous pull token (`ghcr.io/token?scope=repository:plainprogrammer/collector:pull`) reads any version, tagged or not, by digest. GHCR answers 404 `MANIFEST_UNKNOWN` to GET or HEAD unless `Accept` names the manifest's media type (send all four: OCI index/manifest, Docker list/manifest). Index entries can list arm64 before amd64.

**How to apply:** check these before specifying or planning registry, CI or Kamal work. Related: [[spec-012-followups]].
