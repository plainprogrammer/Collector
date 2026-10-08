# Verification: Build and Publish Collector Images (spec 012)

**Spec:** [spec.md](spec.md) v1.1.1 · **Plan:** [plan.md](plan.md) Phases 6 and 7 · **Recorded:** 2026-10-08

Evidence for every acceptance criterion that needs the registry, a workflow run or a running image. File-shape
criteria are covered by `spec/image_publishing_spec.rb` and `spec/readme_spec.rb`, which run in `bin/ci`.

## Runs

| Run | Trigger | Result | Duration |
|---|---|---|---|
| [37787781395](https://github.com/plainprogrammer/Collector/actions/runs/37787781395) | Pull request #15 | `ci`, both image jobs pass; publish skipped | 6m 29s |
| [37788809117](https://github.com/plainprogrammer/Collector/actions/runs/37788809117) | Push to `main`, merge `7b1b1c9` | All pass; first publish (cold cache) | 8m 32s |
| [37789717608](https://github.com/plainprogrammer/Collector/actions/runs/37789717608) | Push to `main`, `63596c6` | All pass | 4m 47s |
| [37794083412](https://github.com/plainprogrammer/Collector/actions/runs/37794083412) attempt 1 | Tag `v0.1.0` | All pass | 4m 42s |
| [37794083412](https://github.com/plainprogrammer/Collector/actions/runs/37794083412) attempt 2 | Re-run of `v0.1.0` | All pass | 4m 28s |

Every run is under the 30-minute target (NFR Performance). The Actions cache is branch-scoped, so the first `main`
run built cold. The native `ubuntu-24.04-arm` runner works for the private repository, so ADR 0010's QEMU
fallback was not needed.

## Pull request (Phase 6)

- **AC-4.2:** `Publish manifest list` was skipped, and `gh api /user/packages/container/collector` answered
  `404 Package not found` after the run. Nothing reached the registry.
- **AC-4.3, AC-6.2:** both image jobs logged `OK: collector:smoke passed the smoke test`.

## First publish and going public (Phase 7)

Each step follows `docs/releasing.md`.

1. **Push the first image (AC-4.1).** After the merge run, the package was `private`, linked to
   `plainprogrammer/Collector`, with one manifest list tagged `["sha-7b1b1c9","edge"]` and no `latest`. Two
   untagged versions are the per-architecture digests that list points to.
2. **Verify an authenticated pull.** After `gh auth token | podman login ghcr.io`, `podman pull …:edge`
   succeeded. `podman manifest inspect` gave `["linux/amd64","linux/arm64"]`, and `bin/image-smoke …:edge`
   passed all five sections.
3. **Confirm the package is linked.** The API reports the repository `plainprogrammer/Collector`. The labels on
   `edge`: source `https://github.com/plainprogrammer/Collector`, version `edge`, revision
   `7b1b1c949f28701c1c0bd93183bd6ec193b56959`, licences `AGPL-3.0`, and the spec's description (AC-3.5 on the
   `main` channel).
4. **Change the visibility to public.** Done by the maintainer in the browser on 2026-10-08. The API then
   reported `public`.
5. **Verify an anonymous pull (AC-1.1).** After `podman logout ghcr.io`, `podman pull …:edge` succeeded, and
   the registry issued an anonymous pull token.

The maintainer's `.kamal/secrets` fix (`63596c6`) then published `edge` and `sha-63596c6`. `sha-7b1b1c9` kept
its manifest list.

## Release `v0.1.0`

- **AC-3.6:** a throwaway lightweight tag `v0.1` on `63596c6` reached the remote, and no run started in the
  following 90 seconds. The tag was then deleted.
- **AC-3.1, AC-2.1:** the annotated tag `v0.1.0` on `63596c6` produced one manifest list tagged
  `["latest","0.1","0.1.0"]`. No `0` tag exists (`podman manifest inspect …:0` fails). The list has exactly
  `linux/amd64` and `linux/arm64`, and the workflow's own check step passed.
- **AC-3.5:** labels on `latest` are source `https://github.com/plainprogrammer/Collector`, version `0.1.0`,
  revision `63596c6f42314c2cb880f48b92aa83c951c74f92`, licences `AGPL-3.0`, and the spec's description.
- **AC-1.1 on `latest`:** pulled anonymously.
- **AC-4.1:** `edge` stayed on `sha-63596c6` through the release.

## Running the published image

- **AC-2.2 (emulated arm64):** `SMOKE_BOOT_ATTEMPTS=300 bin/image-smoke ghcr.io/plainprogrammer/collector:edge
  --platform linux/arm64` on the arm64 variant of `edge` (commit `63596c6`, the same commit as `latest`) passed
  all five sections. A native arm64 host is the maintainer's to try.
- **AC-1.2, AC-1.3, AC-6.2:** with the default `compose.yaml` under project `collector012`:
  - `COLLECTOR_IMAGE=…:edge` booted, `/up` answered 200, and `collector:user` printed `Created admin upgrade@example.com.`
  - `podman compose pull && podman compose up -d` switched to `ghcr.io/plainprogrammer/collector:latest`, which
    reported `Up 12 seconds (healthy)`.
  - `User.exists?(email_address: "upgrade@example.com")` printed `true`, so the data survived the upgrade.
  - Signing in answered `303` to `/collection`, and the signed-in `/scanner` answered `200`.
  - The project was removed with `down -v`.
- **AC-5.1, AC-5.2 (configuration side):** `bin/kamal config` printed
  `:absolute_image: ghcr.io/plainprogrammer/collector:<git sha>` (Phase 3). `bin/kamal config --version 0.1.0`
  printed `:version: 0.1.0` and `:absolute_image: ghcr.io/plainprogrammer/collector:0.1.0`. A live deploy is the
  maintainer's.
- **AC-5.4:** `config/deploy.yml` is covered by its spec. In `.kamal/secrets`, the maintainer found the
  assignment only in comments (`grep -c '^KAMAL_REGISTRY_PASSWORD=' .kamal/secrets` printed `0`). They added
  `KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD` in `63596c6`.

## Re-run of the newest release (AC-3.7)

| | Before | After |
|---|---|---|
| `latest`, `0.1`, `0.1.0` | `sha256:f03eb8274a90…` | `sha256:c2ae8dda3891…` |
| `edge`, `sha-63596c6` | `sha256:22135719995b…` | unchanged |
| `sha-7b1b1c9` | `sha256:74b8c6533814…` | unchanged |

After the re-run, `latest` still lists `linux/amd64` and `linux/arm64`, with version `0.1.0` and revision
`63596c6f42314c2cb880f48b92aa83c951c74f92`. The re-run's smoke steps passed on both architectures.

## Image size

The trimmed image is 550 MB, against 560 MB before `.dockerignore` excluded the development-only paths (Phase 1,
local `podman build`).

## Not yet evidenced

- **AC-3.2:** the `X` tag is only published from release `1.0.0` on. The rule is in `ci.yml` and asserted by the spec.
- **AC-3.3:** waits for the first pre-release tag.
- **AC-5.2's live deploy:** the maintainer's.

## Observation

Running Rails tasks in the image prints "Generating image variants with libvips requires the ruby-vips gem". This
predates spec 012 (the `Dockerfile` installs `libvips` but the `Gemfile` has no `ruby-vips`) and does not affect boot or
these checks.
