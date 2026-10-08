# Feature 012: Build and Publish Collector Images

**Status:** Approved
**Version:** 1.1.1
**Created:** 2026-10-07
**Last Updated:** 2026-10-07
**Branch:** `012-ghcr-registry-publishing`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-07 | Initial draft from the approved [prd.md](prd.md) and ADRs 0008–0010. Approved by the maintainer |
| 1.1.0 | 2026-10-07 | Spec review revisions (Fable, Mode A). **Per-architecture pushes:** a build pushes per-architecture digests; a *publish* is the tags. A failed architecture leaves an untagged digest; no tag is published (Terms, AC-2.3, NFR Reliability). **Attestations off** so a manifest list has exactly two entries (AC-2.1, FR-1). **Re-runs:** same tags, a two-architecture list built from the same commit, not byte-identical content; only the newest release may be re-run (AC-3.7, AC-7.1, Error Scenarios). **Token:** `packages: write` on the build and merge jobs; pull requests never push and the cache never goes to the registry (FR-1, NFR Security). **Kamal checks** via `bin/kamal config --version` (AC-5.1, AC-5.2). **Off-pattern tags** do not trigger the build or publish jobs (AC-3.6, FR-1). **Collateral docs** named (FR-6). **Also:** 7-character SHAs, explicit labels, concrete task outputs (AC-6.3), `podman compose` in AC-1.3, the replaced `image:` line (AC-1.5), `scanner:*` tasks as a Non-Goal |
| 1.1.1 | 2026-10-07 | Second review pass (Fable, READY TO PLAN). Wording: the pre-release suffix is defined (Terms); only the licence and description labels are hard-coded (AC-3.5); PR runs may write the CI cache, never the registry (NFR Security); an off-pattern tag yields no run or a run with only the `ci` job (Error Scenarios); Out of Scope defers to FR-6's named sentences |

---

## Problem Statement

Collector is meant to be easy to self-host, but both supported paths make the self-hoster build the image: Compose builds from a checkout, and Kamal builds and pushes to a registry the self-hoster must provide. A first run needs the source, a container build toolchain and a download of the OCR engine; an upgrade means pulling source and rebuilding. Nothing in the repository names a release, so there is no version to pin to or to report a bug against.

This feature publishes ready-made, public, multi-architecture images from CI, so that running Collector is a pull, and gives the project its first release names.

> **Inputs.** The scope and the decisions come from the approved [prd.md](prd.md) and the accepted ADRs [0008](../../adr/0008-public-images-from-the-private-repository.md) (public images from the private repository), [0009](../../adr/0009-image-tags-and-release-channels.md) (tags and release channels) and [0010](../../adr/0010-native-multi-architecture-image-builds.md) (native per-architecture builds). The registry (GitHub Container Registry, `ghcr.io/plainprogrammer/collector`), the CI service (GitHub Actions, the existing `ci.yml`) and the two deployment paths (Compose, Kamal) are fixed inputs, as spec 001's stack was, so this spec names them. Everything else here is behaviour, not implementation.
>
> **Terms.** A *release* is a git tag `vX.Y.Z`, optionally with a semver pre-release suffix `-<suffix>` where the suffix matches `[0-9A-Za-z.-]+` (for example `-rc.1`). The *`main` channel* is the image published from every push to `main`. A *manifest list* is one image name that resolves to the right architecture on pull. A *build* produces one per-architecture image and, on `main` and release tags, pushes it to the registry by digest, untagged. *Publish* means creating the tagged manifest list from those digests. Pull requests build without pushing anything.

## Goals

- `ghcr.io/plainprogrammer/collector` is a public, anonymously pullable image that runs on `linux/amd64` and `linux/arm64`.
- Releases are git tags. `vX.Y.Z` publishes `X.Y.Z`, `X.Y`, `latest`, and `X` once X ≥ 1; a pre-release publishes only its own version. The first release is `v0.1.0`.
- Every push to `main` publishes `edge` and `sha-<7-character sha>`; pull requests build both architectures and push nothing.
- Nothing is published unless `bin/ci` has passed on the same commit, and nothing but the workflow pushes to the public image.
- The image carries only what it runs: the development-only paths named in FR-3 are excluded before the first public push.
- Self-hosting defaults to the published image: Compose pulls `latest` and upgrades with a pull; Kamal deploys a release by version without building.
- Releasing and the one-time go-public steps are written down, and the README's deployment sections describe the image-based first run and upgrade for both paths.

## Non-Goals

- Build provenance attestations or SBOMs (they need a public repository on the current plan).
- Automating the package's visibility change; it is manual because it cannot be undone.
- Retention or cleanup of `sha-*` images.
- GitHub Releases, release notes or changelog generation.
- Showing the running version inside the app, or a version file in the repository.
- Dependabot updates for the base image.
- A development or test image.
- Making the repository public.
- Running the `scanner:*` findings tasks inside the image. They are development-only research tools that read `spec/fixtures/card_scanner` and the maintainer's corpus, both excluded (FR-3).

## Users and Context

**Primary users:** self-hosters running Collector on an x86 server, a Raspberry Pi 4 or 5, or an Apple Silicon machine with Docker or Podman. They want to start from an image and upgrade in place with one documented command.
**Secondary users:** early adopters who run the latest `main` and report what they find with a reproducible image name; the maintainer, who cuts releases by tagging, deploys with Kamal, and performs the one-time visibility change.
**Usage context:** first run and upgrades on a self-hoster's machine; merges and tags on the repository; a Kamal deploy from the maintainer's machine.
**User mental model:** "pull the image, set a secret, start it" and "a new version is a `pull`". Versions look like every other container image's: `1.2.3`, `1.2`, `latest`, `edge`.

**What this touches:** the CI workflow (today it only runs `bin/ci` on pull requests and pushes to `main`); the `Dockerfile` and `.dockerignore` (today the whole repository is copied into the image, including `docs/`, `spikes/`, `spec/` and `.claude/`); `compose.yaml` (today `build: .`); `config/deploy.yml` (today a placeholder registry with the credentials commented out); the README's Self-hosting section, which documents both paths and must stay in sync. The image is built from the existing `Dockerfile`, which fetches the pinned OCR engine during the build and runs `db:prepare` on boot. The repository has no git tags today. The repository is private; the package will be public (ADR 0008).

## User Stories

### Story 1: First run from the published image

**As a** self-hoster
**I want** to start Collector from the published image with Compose
**So that** I never need the source or a build toolchain

**Acceptance criteria:**

- [ ] **AC-1.1** Given a machine with Podman or Docker and no registry credentials When `podman pull ghcr.io/plainprogrammer/collector:latest` runs Then the pull succeeds without a login.
- [ ] **AC-1.2** Given `compose.yaml` with `SECRET_KEY_BASE` set and no checkout of the source When `podman compose up -d` runs Then the `web` service starts from `ghcr.io/plainprogrammer/collector:latest`, migrations run on boot, and the healthcheck on `/up` reports healthy.
- [ ] **AC-1.3** Given a running instance from the image When a newer `latest` exists and `docker compose pull && docker compose up -d` (or the `podman compose` equivalent) runs Then the instance restarts on the new image, migrations run on boot, and the data in the `collector_storage` volume is kept. Verified by switching between two images (two local builds via `COLLECTOR_IMAGE`, or `edge` and `latest`) with a user created in between.
- [ ] **AC-1.4** Given an image built locally with `docker build -t collector:local .` When `COLLECTOR_IMAGE=collector:local` is set and `docker compose up -d` runs Then the `web` service runs the local image instead of the published one.
- [ ] **AC-1.5** Given `compose.yaml` When it is read Then it names no `build:`, the former `image: collector:latest` line is replaced by `image: ${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}`, and the rest of the service (ports, environment, volume, healthcheck) is unchanged from before this feature.

### Story 2: The image runs on arm64

**As a** self-hoster on a Raspberry Pi or an Apple Silicon machine
**I want** the same image name to work on my architecture
**So that** I follow the same instructions as everyone else

**Acceptance criteria:**

- [ ] **AC-2.1** Given a published tag When `podman manifest inspect ghcr.io/plainprogrammer/collector:<tag>` runs Then the manifest list has exactly two entries, `linux/amd64` and `linux/arm64`, and no attestation entries (FR-1).
- [ ] **AC-2.2** Given an arm64 host When it pulls a published tag and starts the container Then the container boots on arm64 and `/up` reports healthy. Verified on the maintainer's arm64 machine or emulated with `podman run --platform linux/arm64` on the development machine.
- [ ] **AC-2.3** Given a release tag When one architecture's build fails Then no tag for that release is published, so no tag ever resolves to a single-architecture image. The untagged digest from the architecture that succeeded may remain on the registry (cleanup is out of scope).

### Story 3: Cutting a release

**As the** maintainer
**I want** a pushed `vX.Y.Z` tag to publish the release
**So that** releasing is one git command

**Acceptance criteria:**

- [ ] **AC-3.1** Given `bin/ci` passes on the tagged commit When the tag `v0.1.0` is pushed Then the registry has `0.1.0`, `0.1` and `latest`, all resolving to the same manifest list, and no `0` tag.
- [ ] **AC-3.2** Given a release tag `vX.Y.Z` with X ≥ 1 When it is published Then the registry has `X.Y.Z`, `X.Y`, `X` and `latest`.
- [ ] **AC-3.3** Given a pre-release tag such as `v1.0.0-rc.1` When it is published Then the registry has `1.0.0-rc.1` and `latest`, `1.0` and `1` are not changed.
- [ ] **AC-3.4** Given a pushed tag on a commit where `bin/ci` fails When the workflow finishes Then nothing is pushed to the registry.
- [ ] **AC-3.5** Given a published image When `podman inspect` reads its labels Then `org.opencontainers.image.source` is the repository URL, `.version` is the tag's version (`edge` on the `main` channel), `.revision` is the commit SHA, and, set explicitly by the workflow rather than taken from the repository's settings, `.licenses` is `AGPL-3.0` and `.description` is "Self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards."
- [ ] **AC-3.6** Given any pushed tag When it does not match `vX.Y.Z` or `vX.Y.Z-<suffix>` (for example `v1.2` or `release-1`) Then the build and publish jobs do not run for it and nothing is pushed.
- [ ] **AC-3.7** Given the newest release already published When its workflow is re-run Then the same tags point at a new two-architecture manifest list built from the same commit (labels `.version` and `.revision` identical, AC-6.1 to AC-6.3 hold), and no tag outside that release's set changes. Byte-identical layers are not required.

### Story 4: Running ahead on `main`

**As an** early adopter
**I want** an image of the latest `main`
**So that** I can try a change and report a bug with an image name

**Acceptance criteria:**

- [ ] **AC-4.1** Given `bin/ci` passes on a push to `main` When the workflow finishes Then the registry has `edge` and `sha-<7-character sha>` resolving to the same manifest list, and `latest` is unchanged.
- [ ] **AC-4.2** Given a pull request When its workflow runs Then both architectures are built and the registry receives nothing: no new tags, no new untagged digests, and no build cache.
- [ ] **AC-4.3** Given a pull request whose `Dockerfile` or `.dockerignore` change breaks the build When the workflow runs Then the run fails and the failure names the build job, before merge.

### Story 5: Deploying a release with Kamal

**As the** maintainer
**I want** Kamal to deploy a published release without building
**So that** servers run the same image self-hosters pull

**Acceptance criteria:**

- [ ] **AC-5.1** Given `config/deploy.yml` When `bin/kamal config` runs Then it validates and prints `absolute_image: ghcr.io/plainprogrammer/collector`; the file names the registry server `ghcr.io`, the image `plainprogrammer/collector`, the username `plainprogrammer` and the password `KAMAL_REGISTRY_PASSWORD` (AC-5.4).
- [ ] **AC-5.2** Given a published release `X.Y.Z` When `bin/kamal deploy --skip-push --version X.Y.Z` runs Then Kamal pulls `ghcr.io/plainprogrammer/collector:X.Y.Z` on the servers and does not build or push. Verified by `bin/kamal config --version X.Y.Z` printing `version: X.Y.Z` with that `absolute_image`; a live deploy is the maintainer's check (Kamal has no dry run).
- [ ] **AC-5.3** Given the README's Kamal section When it is read Then it documents the `--skip-push --version X.Y.Z` deploy, says a self-hoster who wants Kamal to build their own image changes `image` and `registry` to a registry they own first, and says never to run a plain `bin/kamal deploy` against `ghcr.io/plainprogrammer/collector` because it would overwrite the public `latest` with a single-architecture image.
- [ ] **AC-5.4** Given the deploy file When it is read Then the registry credentials are active, not commented out, and `.kamal/secrets` still reads the password from `KAMAL_REGISTRY_PASSWORD`.

### Story 6: The image carries only what it runs

**As a** self-hoster
**I want** the image to contain the app and nothing else
**So that** it is smaller and nothing development-only ships to the public

**Acceptance criteria:**

- [ ] **AC-6.1** Given the built image When its filesystem is listed Then none of these exist under `/rails`: `docs/`, `spikes/`, `spec/`, `script/`, `.claude/`, `CLAUDE.md`, `.githooks/`, `orca.yaml`, `.worktreeinclude`.
- [ ] **AC-6.2** Given the built image When it starts with a `SECRET_KEY_BASE` Then it boots, migrates, serves the home page, serves `/scanner` to a signed-in user, and serves the OCR engine files under `/ocr/v7.0.0/`.
- [ ] **AC-6.3** Given the built image When `bin/rails "catalog:status[mtg]"` and `bin/rails "collector:user[you@example.com]"` run in it Then `catalog:status` prints its status (`No mtg refresh runs yet.` on a fresh instance) and `collector:user`, with `COLLECTOR_PASSWORD` set, prints that it created the admin.
- [ ] **AC-6.4** Given the built image When `config/master.key`, `.env*`, `storage/` and `.kamal/` are checked Then none are present (unchanged from today's `.dockerignore`, re-asserted because the image is now public).

### Story 7: Releasing and going public are written down

**As the** maintainer
**I want** the release procedure and the one-time go-public steps documented
**So that** a release months from now follows the same steps

**Acceptance criteria:**

- [ ] **AC-7.1** Given `docs/releasing.md` When it is read Then it says a release is an annotated `vX.Y.Z` tag on `main` pushed to the repository, that the first release is `v0.1.0`, what each trigger publishes (the table from ADR 0009), that the workflow publishes on any tag push matching `vX.Y.Z` or `vX.Y.Z-<suffix>` while "annotated, on `main`" is procedure, and that only the newest release's workflow may be re-run, because re-running an older one would move `latest`, `X` and `X.Y` back.
- [ ] **AC-7.2** Given `docs/releasing.md` When it is read Then it has the go-public checklist in this order: push the first image, verify an authenticated pull, link the package to the repository, change the package's visibility to public, verify an anonymous pull; and it says the change cannot be undone.
- [ ] **AC-7.3** Given the README's Self-hosting section When it is read Then the Compose subsection describes the first run from the image (no checkout), the `COLLECTOR_IMAGE` variable in its table, the upgrade as `docker compose pull && docker compose up -d`, and building from source as the alternative; the "Upgrading to accounts" steps say to pull the image, not the code; and the Kamal subsection describes the image-based deploy (AC-5.3) so neither path still documents building as the default.
- [ ] **AC-7.4** Given the README's Card scanner subsection When it is read Then the sentence about the image build downloading the OCR engine still holds for the published image, and says the published image already contains it.

## Functional Requirements

### FR-1: Publishing triggers and the gate

The workflow publishes images only after `bin/ci` has passed on the same commit, and only for pushes to `main` and tags matching `vX.Y.Z` or `vX.Y.Z-<suffix>`.

**Must:**
- Run `bin/ci` on matching tag pushes as well as on pull requests and pushes to `main`, and make the build and publish jobs depend on it.
- Build both architectures on pull requests, pushes to `main` and release tags.
- Push nothing on pull requests and on failed `bin/ci`; publish no tag when either architecture's build fails.
- Not run the build or publish jobs for tags that do not match `vX.Y.Z` or `vX.Y.Z-<suffix>`.
- Authenticate to the registry with the workflow's own token; grant `packages: write` only to the build and merge jobs.
- Build each per-architecture image without provenance or SBOM attestations, so every manifest list has exactly two entries.

**Must not:**
- Publish a manifest list that lacks either architecture.
- Push from anywhere but the workflow (the maintainer's Kamal deploys use `--skip-push`).
- Send build cache to the registry; the cache lives in the CI service's own cache.

### FR-2: Tags and labels

**Must:**
- Follow ADR 0009's table: `vX.Y.Z` → `X.Y.Z`, `X.Y`, `latest`, and `X` when X ≥ 1; `vX.Y.Z-<suffix>` → `X.Y.Z-<suffix>` only; push to `main` → `edge`, `sha-<7-character sha>`.
- Make all tags of one run resolve to one manifest list.
- Set the OCI labels named in AC-3.5 on every per-architecture image, with the licence and description given explicitly rather than taken from the repository's settings.

**Must not:**
- Publish a `0` tag for `0.y.z` releases.
- Move `latest` on a pre-release or on the `main` channel.

### FR-3: Image contents

**Must:**
- Exclude from the build context: `docs/`, `spikes/`, `spec/`, `script/`, `.claude/`, `CLAUDE.md`, `.githooks/`, `orca.yaml`, `.worktreeinclude`, in addition to everything `.dockerignore` excludes today.
- Keep the runtime unchanged: Thruster in front of Puma, non-root uid 1000, `db:prepare` on boot, the OCR engine fetched and verified during the build.
- Keep the `-j 1` bootsnap precompile workaround (ADR 0010).

**Must not:**
- Change what the image does at runtime for anyone already running a locally built image.

### FR-4: Compose

**Must:**
- Default `compose.yaml` to `image: ${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}` with no `build:`.
- Document `COLLECTOR_IMAGE` in the file's header comment and in the README's variable table.
- Work with `docker compose` and `podman compose`.

**Must not:**
- Change any other service setting (port mapping, environment, volume, healthcheck).

### FR-5: Kamal

**Must:**
- Point `config/deploy.yml` at registry `ghcr.io`, image `plainprogrammer/collector`, username `plainprogrammer`, password from `KAMAL_REGISTRY_PASSWORD`; the placeholder server stays.
- Validate with `bin/kamal config`.
- Document the `--skip-push --version X.Y.Z` deploy and the self-build alternative (change `image` and `registry`).

**Must not:**
- Document or encourage a plain `bin/kamal deploy` against the public image.

### FR-6: Documentation

**Must:**
- Add `docs/releasing.md` with the release procedure, the publish table and the go-public checklist (AC-7.1, AC-7.2).
- Update the README's Self-hosting section for both paths together (AC-7.3, AC-7.4, AC-5.3), and the Compose header comment.
- Keep the README's statement that Dependabot keeps GitHub Actions up to date true for the new actions (the `github-actions` ecosystem is already configured).
- Update the sentences this feature makes stale: `CLAUDE.md` ("GitHub Actions runs only `bin/ci`" and Kamal's "placeholder server/registry"), the README's Testing and CI sentence ("runs `bin/ci`, so local and hosted CI are the same") and Self-hosting introduction ("Both use the `Dockerfile` in this repository"), `.claude/memory/steering/tech-stack.md` (both paths build the `Dockerfile`; CI runs `bin/ci`), and the Release Process placeholder in `.claude/memory/steering/team-practices.md`, which points at `docs/releasing.md`.

**Must not:**
- Leave any README instruction that says to pull the source and rebuild as the upgrade path.

## Non-Functional Requirements

### Performance

- A pull-request run (`bin/ci` plus both builds) and a publish run each complete within 30 minutes on the repository's standard runners. The plan records the first measured durations; if a run is slower, that is reported, not hidden.
- Layer caching, held in the CI service's cache rather than the registry, is used so that a run with no `Gemfile.lock` change does not reinstall gems from scratch.

### Security

- `packages: write` is granted only to the build and merge jobs; pull-request runs of those jobs never push an image or a cache to the registry (writing the CI service's own cache is allowed) and the merge job does not run for them.
- No secret enters the image: `config/master.key`, `.env*`, `.kamal/` and `storage/` stay excluded (AC-6.4). The image needs only `SECRET_KEY_BASE` (Compose) or `RAILS_MASTER_KEY` (Kamal) at runtime, as today.
- The image runs as the non-root user and exposes the same port as today.
- The source becomes readable by anyone who pulls the image (ADR 0008); nothing in the repository that must stay private may be inside the build context.

### Reliability

- A publish is all-or-nothing: either every tag of the run points at a complete two-architecture manifest list, or no tag is published (an untagged per-architecture digest may remain).
- Re-running the newest release's workflow is safe: it produces the same tags on a list built from the same commit (AC-3.7). Re-running an older release's workflow is forbidden by `docs/releasing.md`.
- If arm64 hosted runners become unavailable to the repository, the build falls back to emulation on the amd64 runner without changing tags or documentation (ADR 0010); this is a plan change, not a spec change.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| `bin/ci` fails on a tag or on `main` | The build and publish jobs do not run; nothing is pushed; the run is red. |
| One architecture's build fails | No tag is published for that run; the run is red and names the failing architecture; the other architecture's untagged digest may remain. |
| The OCR engine download fails during the build (registry unreachable or checksum mismatch) | The build fails and nothing is published; re-running the workflow retries. |
| A tag that does not match the release pattern is pushed (for example `v1.2` or `release-1`) | The build and publish jobs do not run; nothing is pushed; there is no run, or a run with only the `ci` job, and it is not red for that reason. |
| The maintainer runs a plain `bin/kamal deploy` | Not prevented by software; the README says not to, and `docs/releasing.md` repeats it. If it happens, re-running the newest release's workflow restores `latest` (AC-3.7). |
| An older release's workflow is re-run | `latest`, `X` and `X.Y` move back to it. Forbidden by `docs/releasing.md`; recovered by re-running the newest release's workflow. |
| An anonymous pull fails with "denied" | The package is still private; the go-public checklist's visibility step has not been done. |
| The package is made public before the hygiene change lands | It cannot be made private again; the package is deleted and re-published after the fix. `docs/releasing.md` orders the steps to avoid this. |
| arm64 runners are unavailable to the private repository | The run fails on the arm64 job; the fallback in ADR 0010 is applied as a plan change. |
| `COLLECTOR_IMAGE` names an image that does not exist | Compose fails to pull and reports the image name; nothing else starts. |
| A self-hoster upgrades a locally built instance to the published image | Supported: the volume and its databases are the same; `db:prepare` runs on boot. |

## Open Questions

None. The brainstorm resolved the go-public timing (before the repository), the triggers and tags (ADR 0009), the architectures and build strategy (ADR 0010), the consumer defaults (pull by default) and the gate (`bin/ci` before any publish; pull requests build).

## Out of Scope (Future Considerations)

- Build provenance attestations and SBOMs once the repository is public (one more job after the merge step).
- Throttling the `main` channel (for example, skipping docs-only pushes) to save Actions minutes.
- Cleanup of `sha-*` images and untagged manifests on the registry.
- GitHub Releases with notes, and a changelog.
- A version shown in the app's footer or on `/up`.
- Dependabot for the base image, and a second registry or mirror.
- A development image or a devcontainer.
- Fixing stale README text outside the Self-hosting section, other than the sentences FR-6 names (for example, the introduction still says accounts are not built).
