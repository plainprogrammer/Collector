# Releasing Collector

A release is a git tag. CI builds the image for amd64 and arm64, smoke-tests it, and publishes it to
`ghcr.io/plainprogrammer/collector` once `bin/ci` has passed on the tagged commit (spec 012, ADRs 0008–0010).

## What each trigger publishes

| Trigger | Tags published |
|---|---|
| Pull request | none (both architectures are built and smoke-tested) |
| Push to `main` | `edge`, `sha-<7-character sha>` |
| Tag `vX.Y.Z` | `X.Y.Z`, `X.Y`, `latest`, and `X` when X ≥ 1 (no bare `0` for `0.y.z`) |
| Tag `vX.Y.Z-<suffix>` (pre-release, suffix `[0-9A-Za-z.-]+`) | `X.Y.Z-<suffix>` only; `latest` does not move |

The workflow publishes on any tag push matching those two patterns. Any other tag (`v1.2`, `release-1`) runs
nothing. The workflow does not check that the tag is annotated or on `main`; that is procedure (step 2 below).
A pre-release suffix must be valid semver: a tag such as `v1.2.3-rc_1` matches the trigger but publishes
nothing and fails the run. Every published image carries OCI labels for its source, version, revision, licence
and description.

## Cutting a release

1. Make sure `main` is green and contains everything the release needs.
2. Tag it, annotated, on `main`, and push the tag. The first release is `v0.1.0`.

   ```sh
   git switch main && git pull
   git tag -a v0.1.0 -m "Collector 0.1.0"
   git push origin v0.1.0
   ```

3. Watch the run (`gh run watch`) until `Publish manifest list` is green, then check:

   ```sh
   podman manifest inspect ghcr.io/plainprogrammer/collector:0.1.0 | grep -E '"(architecture|os)"'
   ```

   Both `amd64` and `arm64` appear, with `linux`.

4. Deploy with Kamal by version: `bin/kamal deploy --skip-push --version 0.1.0`. Never run a plain
   `bin/kamal deploy` against the public image.

**Re-runs.** Only the newest release's workflow may be re-run: a re-run moves `latest`, `X` and `X.Y` to the
commit it builds, so re-running an older release would point them backwards. A re-run of the newest release
is safe and is how `latest` is restored if something else overwrote it.

## Going public (one time)

Images are public although the repository is still private (ADR 0008). The package is created private by the
first push and is made public by hand, in this order. Changing a package to public **cannot be undone**; the
only way back is deleting the package.

1. Push the first image: merge to `main` so the workflow publishes `edge`. Confirm with
   `gh api /user/packages/container/collector --jq .visibility` (prints `private`).
2. Verify an authenticated pull on the development machine:

   ```sh
   gh auth token | podman login ghcr.io -u plainprogrammer --password-stdin
   podman pull ghcr.io/plainprogrammer/collector:edge
   bin/image-smoke ghcr.io/plainprogrammer/collector:edge
   ```

3. Confirm the package is linked to the repository: open
   https://github.com/users/plainprogrammer/packages/container/package/collector and check that the
   repository appears under the package name (the `org.opencontainers.image.source` label links it). Check
   that the package's description and licence read as the labels set them.
4. Change the visibility to public: on that page, **Package settings** → **Danger zone** →
   **Change visibility** → **Public**, and type the package name to confirm.
5. Verify an anonymous pull, with no credentials:

   ```sh
   podman logout ghcr.io
   podman pull ghcr.io/plainprogrammer/collector:edge
   ```

Then cut `v0.1.0` as above so that `latest` exists for the README's instructions.
