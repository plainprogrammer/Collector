# Implementation Plan: Build and Publish Collector Images

**Spec:** docs/specs/012-ghcr-registry-publishing/spec.md (v1.1.1, Approved, reviewed twice)
**Decisions:** [ADR 0008](../../adr/0008-public-images-from-the-private-repository.md) (public images from the private repository), [0009](../../adr/0009-image-tags-and-release-channels.md) (tags and release channels), [0010](../../adr/0010-native-multi-architecture-image-builds.md) (native per-architecture builds), all Accepted.
**Created:** 2026-10-07
**Revised:** 2026-10-07, after a read-only plan review (Fable, NEEDS REVISION). Blocking fixes: the smoke script creates the admin before the page checks (a fresh instance redirects every page to `/registration/new` until a user exists); `not_include` is not a matcher; the releasing expectation matches the doc's capitalised sentence; the README scanner sentence stays on one line. Also: a `step(id)` helper instead of three memoised helpers (RuboCop limit), `SMOKE_BOOT_ATTEMPTS` for emulated runs, the real `bin/kamal config` output form, the `.kamal/secrets` half of AC-5.4 as a maintainer check, two README replacement targets made precise, the PR body's session line, and the cold-cache note for the first `main` run.
**Approved:** 2026-10-07 (maintainer, as drafted; revision pending their confirmation).

## Context

Both self-hosting paths build the `Dockerfile` themselves today, nothing names a release, and the image copies the whole repository. This plan adds two jobs to the existing CI workflow that build the image natively on amd64 and arm64 runners, smoke-test it, push each architecture by digest and publish one tagged manifest list; trims the build context; makes Compose and Kamal consume the published image; and writes the release procedure. The first publish and the one-way visibility change happen after the merge, as the last phase.

**Facts established during planning (2026-10-07):**

- **The workflow today** (`.github/workflows/ci.yml`): one job `ci` on `pull_request` and `push` to `main`: `actions/checkout@v7`, `ruby/setup-ruby@v1` with `bundler-cache`, `bin/ci`, and `actions/upload-artifact@v7` of `tmp/capybara` on failure. `.github/dependabot.yml` already covers the `github-actions` ecosystem. The repository's default token permissions are not restricted, so a workflow-level `permissions:` block is needed to keep `packages: write` off the `ci` job.
- **Current action majors** (checked 2026-10-07 against Docker's `metadata-action` README examples): `docker/setup-buildx-action@v4`, `docker/login-action@v4`, `docker/metadata-action@v6`, `docker/build-push-action@v7`, `actions/checkout@v7`. `actions/download-artifact` follows `upload-artifact`'s major (`v7` in this repo); Phase 4 verifies the tag exists before pinning.
- **Tag filters:** GitHub's filter patterns support `+` and `[0-9]` ranges; `v[0-9]+.[0-9]+.[0-9]+` is the documented semver example. Two patterns, one for releases and one for pre-releases (`-*`), replace a `v*` catch-all so an off-pattern tag never triggers the build jobs (AC-3.6).
- **Metadata-action behaviour:** `type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}` is Docker's own "major version zero" example; pre-release tags only extend `{{version}}`; `latest=auto` adds `latest` for non-pre-release semver tags only; `type=sha` defaults to `sha-` plus 7 characters; `type=edge,branch=main` only fires on pushes to `main`. `type=sha` would also fire on tag pushes, so it is gated with `enable=${{ github.ref == 'refs/heads/main' }}`. The action exports `DOCKER_METADATA_OUTPUT_JSON` for the merge step. The generated `org.opencontainers.image.source` label is what GHCR uses to link a package to its repository, so "link the package" in the checklist is a verification, not an action.
- **Attestations:** `build-push-action` adds a provenance attestation by default when pushing, which would give the manifest list four entries; `provenance: false` and `sbom: false` keep it at two (AC-2.1).
- **Kamal 2.12.0:** `bin/kamal config` prints YAML with symbol keys, e.g. `:absolute_image: ghcr.io/plainprogrammer/collector:<version>` and `:version: <git sha, or the --version value>`; `--version` is a class option; `--skip-push` (`-P`) runs `build:pull` instead of `build:deliver`; the registry validator requires `username` and `password` for any non-`localhost` server; there is no dry run. `config/master.key` is present in this worktree (copied by `.worktreeinclude`), so `bin/kamal config` runs.
- **Runtime paths** (for the smoke script): `/up` (health); until a user exists the `FirstRun` concern redirects every other page to `/registration/new` (200), so the script creates the admin before checking pages; after that `/session/new` (sign-in, unauthenticated) is 200 and `/scanner` redirects to `/session/new` when signed out; `/ocr/v7.0.0/tesseract.min.js` and `/ocr/v7.0.0/lang/eng.traineddata.gz` (unauthenticated, from `Collector::OcrEngine::FILES`). Thruster listens on `HTTP_PORT`; `compose.yaml` uses 8080. `bin/rails "catalog:status[mtg]"` prints `No mtg refresh runs yet.` on a fresh instance; `bin/rails "collector:user[a@b]"` with `COLLECTOR_PASSWORD` prints `Created admin a@b.` (`User::PASSWORD_MINIMUM` is 12).
- **Nothing the image runs reads the excluded paths.** `lib/collector/scanner_findings/*` and `lib/tasks/scanner.rake` hold `spec/fixtures/card_scanner` paths as constants or inside task bodies; `lib/collector/worktree_setup.rb` names `.githooks` as a string. Eager loading in production defines constants only.
- **Dockerfile:** `COPY vendor/* ./vendor/` runs before `COPY . .`; `vendor/ocr/` is gitignored, so CI builds always fetch the OCR engine (the "download fails" error row is a real path). `-j 1` bootsnap stays (ADR 0010).
- **File-shape specs** are an existing pattern: `spec/project_config_spec.rb` parses `orca.yaml` and `.worktreeinclude`; `spec/readme_spec.rb` slices README sections with regexes. Both are excluded from `RSpec/DescribeClass` in `.rubocop.yml`; the new spec file joins that list. `RSpec/ExampleLength` max is 15; multi-expectation examples use `:aggregate_failures`. Psych parses the YAML key `on` as `true`.
- **Dev machine:** Podman 5.8.7 with `podman manifest` and `podman compose`; `qemu-aarch64-static` is registered with binfmt, so `podman run --platform linux/arm64` works for AC-2.2. `gh` 2.97 is logged in as `plainprogrammer` with `read:packages` (enough for the authenticated pull; the visibility change is done in the browser). A local `localhost/collector:latest` image exists from an earlier Compose build.
- **Branch:** the worktree is on `plainprogrammer/012-ghcr-registry-publishing`; the convention branch is `012-ghcr-registry-publishing`, created from HEAD in Phase 0.

**Plan decisions (not spelled out in the spec):**

- **Smoke before push.** Each architecture's runner builds once with `load: true`, runs `bin/image-smoke` against the loaded image, then builds again with the push-by-digest output; the second build is served entirely from the first's cache. Pull requests therefore get the runtime check (AC-4.3, AC-6.2) and nothing is pushed unless the smoke passed.
- **One spec file for the file shapes:** `spec/image_publishing_spec.rb` covers `.dockerignore`, `compose.yaml`, `config/deploy.yml`, `.github/workflows/ci.yml` and `docs/releasing.md`; README checks go in `spec/readme_spec.rb` beside the existing ones.
- **`bin/image-smoke`** is a bash script because the workflow and the dev machine run it on the host with `docker` or `podman`; it lives in `bin/` beside `bin/fetch-ocr-engine` and `bin/dev-certificate`.
- **Cache scope** is the platform with `/` replaced by `-`, held in the Actions cache (`type=gha`), never the registry.
- **Build-from-source for Compose** is `docker build -t collector:local .` then `COLLECTOR_IMAGE=collector:local`; `compose.yaml` no longer carries `build:`.

## Global Constraints

- The image is `ghcr.io/plainprogrammer/collector`, public, runs on `linux/amd64` and `linux/arm64`.
- `vX.Y.Z` → `X.Y.Z`, `X.Y`, `latest`, and `X` when X ≥ 1; `vX.Y.Z-<suffix>` → `X.Y.Z-<suffix>` only; push to `main` → `edge`, `sha-<7-character sha>`. The first release is `v0.1.0`. No `0` tag for `0.y.z`.
- Pull requests build both architectures and push nothing: no image, no untagged digest, no registry cache.
- Nothing is published unless `bin/ci` has passed on the same commit; `packages: write` only on the build and merge jobs.
- Every manifest list has exactly two entries; per-architecture images are built without provenance or SBOM attestations.
- A tag that does not match `vX.Y.Z` or `vX.Y.Z-<suffix>` (suffix `[0-9A-Za-z.-]+`) does not run the build or publish jobs.
- Excluded from the build context: `docs/`, `spikes/`, `spec/`, `script/`, `.claude/`, `CLAUDE.md`, `.githooks/`, `orca.yaml`, `.worktreeinclude`, in addition to today's `.dockerignore`. Runtime unchanged: Thruster, uid 1000, `db:prepare` on boot, OCR engine fetched during the build, `-j 1` bootsnap kept.
- `compose.yaml`: `image: ${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}`, no `build:`, nothing else changed.
- `config/deploy.yml`: registry `ghcr.io`, image `plainprogrammer/collector`, username `plainprogrammer`, password `KAMAL_REGISTRY_PASSWORD`, placeholder server kept; the README never encourages a plain `bin/kamal deploy` against the public image.
- OCI labels: `source`, `version` (`edge` on `main`), `revision`, and explicitly `licenses=AGPL-3.0` and `description=Self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards.`
- Only the newest release's workflow may be re-run.
- Each run (pull request or publish) completes within 30 minutes; the measured durations are recorded.
- Commits follow `docs/git-convention.md` (`<type>(<scope>): <message>`), one per step, with the attribution trailers; the pre-commit hook runs RuboCop on staged Ruby files and Brakeman, and the pre-push hook runs `bin/ci`.

---

## Goal

A merge to `main` or a `vX.Y.Z` tag publishes `ghcr.io/plainprogrammer/collector` for amd64 and arm64 after `bin/ci` passes; Compose and Kamal run that image; `docs/releasing.md` tells the maintainer how to release and how to make the package public.

---

## Phase 0: Environment, the branch, and the smoke script

**Implements:** FR-3 (verification tool) | **Satisfies:** AC-6.2, AC-6.3 (the checks exist and run against the current image)
**Files:** `bin/image-smoke` (new)
**Interfaces:** Consumes: nothing. Produces: `bin/image-smoke <image> [run flags]`, exit 0 when every check passes, used by Phase 1 (locally) and Phase 4 (in the workflow).

Create the branch, confirm the tools, and write the smoke script. Run it against an image built from the current tree: the boot, page and task checks pass, and the hygiene check fails by listing the development-only paths. That failure is Phase 1's red.

- [ ] Create the convention branch from the current HEAD (the spec commits are on it):
  ```sh
  git switch -c 012-ghcr-registry-publishing
  ```
  Expected: `Switched to a new branch '012-ghcr-registry-publishing'`.
- [ ] Confirm the tools:
  ```sh
  podman --version && podman manifest --help >/dev/null && echo manifest-ok
  cat /proc/sys/fs/binfmt_misc/qemu-aarch64 | head -1
  gh auth status 2>&1 | grep -o "read:packages"
  bin/kamal version
  ```
  Expected: `podman version 5.8.7`, `manifest-ok`, `enabled`, `read:packages`, `2.12.0`.
- [ ] Build the baseline image from the current tree (network needed for gems and the OCR engine; several minutes):
  ```sh
  podman build -t collector:baseline .
  ```
  Expected: ends with `Successfully tagged localhost/collector:baseline`.
- [ ] Write `bin/image-smoke`:
  ```bash
  #!/usr/bin/env bash
  # Smoke-tests a built Collector image (spec 012, AC-6.1 to AC-6.4): boots it, checks the pages and files it must
  # serve, runs the operational rake tasks, then checks that development-only paths and secrets are absent.
  #
  #   bin/image-smoke <image> [extra `run` flags, e.g. --platform linux/arm64]
  #
  # Uses docker when present, else podman (override with CONTAINER_CLI). Exit status 0 means every check passed.
  set -euo pipefail

  image="${1:?usage: bin/image-smoke <image> [run flags]}"
  shift
  run_flags=("$@")
  cli="${CONTAINER_CLI:-$(command -v docker >/dev/null 2>&1 && echo docker || echo podman)}"
  name="collector-smoke-$$"
  attempts="${SMOKE_BOOT_ATTEMPTS:-60}" # 2 s each; raise it for emulated runs

  cleanup() { "$cli" rm -f "$name" >/dev/null 2>&1 || true; }
  trap cleanup EXIT
  fail() { echo "FAIL: $*" >&2; exit 1; }
  status() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}$1"; }

  echo "== boot ${image}"
  "$cli" run -d --name "$name" "${run_flags[@]}" -p 127.0.0.1::8080 \
    -e SECRET_KEY_BASE=smoke-only-not-a-secret -e HTTP_PORT=8080 -e SOLID_QUEUE_IN_PUMA=true "$image" >/dev/null
  port="$("$cli" port "$name" 8080 | head -n 1 | sed 's/.*://')"
  for _ in $(seq 1 "$attempts"); do
    [ "$(status /up)" = "200" ] && break
    sleep 2
  done
  [ "$(status /up)" = "200" ] || { "$cli" logs "$name" >&2; fail "/up did not answer 200 within $((attempts * 2)) s"; }

  echo "== first run"
  [ "$(status /registration/new)" = "200" ] || fail "first-run registration page did not render"

  echo "== operational tasks"
  "$cli" exec "$name" bin/rails "catalog:status[mtg]" | grep -q "mtg" || fail "catalog:status[mtg]"
  "$cli" exec -e COLLECTOR_PASSWORD=smoke-password-1234 "$name" bin/rails "collector:user[smoke@example.com]" \
    | grep -q "Created admin smoke@example.com." || fail "collector:user"

  echo "== pages and assets (a user exists now, so first-run redirects are over)"
  [ "$(status /session/new)" = "200" ] || fail "sign-in page did not render"
  [ "$(status /scanner)" = "302" ] || fail "/scanner should redirect to sign-in when signed out"
  [ "$(status /ocr/v7.0.0/tesseract.min.js)" = "200" ] || fail "OCR engine is not served"
  [ "$(status /ocr/v7.0.0/lang/eng.traineddata.gz)" = "200" ] || fail "OCR language data is not served"

  echo "== development-only paths and secrets must be absent"
  present="$("$cli" exec "$name" sh -c '
    cd /rails
    for path in docs spikes spec script .claude CLAUDE.md .githooks orca.yaml .worktreeinclude config/master.key .kamal; do
      [ -e "$path" ] && echo "$path"
    done
    ls -d .env* 2>/dev/null
    exit 0')"
  [ -z "$present" ] || fail "present in the image:"$'\n'"$present"

  echo "OK: ${image} passed the smoke test"
  ```
- [ ] Make it executable and run it against the baseline:
  ```sh
  chmod +x bin/image-smoke
  bin/image-smoke collector:baseline; echo "exit $?"
  ```
  Expected: `== boot`, `== first run`, `== operational tasks`, `== pages and assets` pass, then `FAIL: present in the image:` listing `docs`, `spikes`, `spec`, `script`, `.claude`, `CLAUDE.md`, `.githooks`, `orca.yaml`, `.worktreeinclude`, and `exit 1`. If an earlier check fails, fix the script's expectation against the real response (the paths and outputs are in Context), not the image.
- [ ] Commit: `test(image): add bin/image-smoke for built Collector images (012)`

---

## Phase 1: Image hygiene

**Implements:** FR-3 | **Satisfies:** AC-6.1, AC-6.2, AC-6.3, AC-6.4
**Files:** `.dockerignore`, `spec/image_publishing_spec.rb` (new), `.rubocop.yml`
**Interfaces:** Consumes: `bin/image-smoke` (Phase 0). Produces: `spec/image_publishing_spec.rb` with a top-level `RSpec.describe "Image publishing files"`, to which Phases 2 to 5 add `describe` blocks; the image `collector:local` built from the trimmed context, used by Phase 2.

Exclude the development-only paths from the build context and prove the image still boots, serves the scanner's assets and runs the operational tasks.

- [ ] Write the failing file-shape spec, `spec/image_publishing_spec.rb`:
  ```ruby
  require "rails_helper"
  require "yaml"

  # File-shape checks for the image publishing flow (spec 012). The registry-side criteria are evidenced by
  # workflow runs and podman output (docs/specs/012-ghcr-registry-publishing/verification.md).
  RSpec.describe "Image publishing files" do
    describe ".dockerignore" do
      let(:rules) do
        Rails.root.join(".dockerignore").readlines(chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
      end

      it "keeps development-only paths out of the build context (AC-6.1, FR-3)" do
        expect(rules).to include("/docs", "/spikes", "/spec", "/script", "/.claude", "/CLAUDE.md", "/.githooks",
                                 "/orca.yaml", "/.worktreeinclude")
      end

      it "still keeps secrets and data out (AC-6.4)" do
        expect(rules).to include("/config/master.key", "/.env*", "/.kamal", "/storage/*")
      end
    end
  end
  ```
- [ ] Exclude it from `RSpec/DescribeClass` in `.rubocop.yml` (the list is alphabetical):
  ```yaml
  RSpec/DescribeClass:
    Exclude:
      - "spec/design_system_files_spec.rb"
      - "spec/githooks/post_checkout_spec.rb"
      - "spec/image_publishing_spec.rb"
      - "spec/network_isolation_spec.rb"
      - "spec/project_config_spec.rb"
      - "spec/readme_spec.rb"
      - "spec/tasks/collector_rake_spec.rb"
  ```
  and extend the comment above it with: `The image publishing spec checks the publishing files.`
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `2 examples, 1 failure` (the development-only paths example fails; the secrets example already passes).
- [ ] Append to `.dockerignore`:
  ```
  # Ignore development-only files: documentation, spikes, the test suite, research scripts and agent/worktree
  # configuration. The published image is public (spec 012), so it carries only what it runs.
  /docs
  /spikes
  /spec
  /script
  /.claude
  /CLAUDE.md
  /.githooks
  /orca.yaml
  /.worktreeinclude
  ```
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `2 examples, 0 failures`.
- [ ] Rebuild and smoke-test:
  ```sh
  podman build -t collector:local .
  bin/image-smoke collector:local; echo "exit $?"
  ```
  Expected: all four sections pass, `OK: collector:local passed the smoke test`, `exit 0`.
- [ ] Compare sizes (recorded in Phase 7's verification notes):
  ```sh
  podman images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E "collector:(baseline|local)"
  ```
- [ ] Run `bin/rubocop` — expect: `no offenses detected`.
- [ ] Commit: `feat(image): keep development-only paths out of the build context (012)`

---

## Phase 2: Compose pulls the published image

**Implements:** FR-4 | **Satisfies:** AC-1.4, AC-1.5 (AC-1.1 to AC-1.3 need the published image: Phase 7)
**Files:** `compose.yaml`, `spec/image_publishing_spec.rb`
**Interfaces:** Consumes: `collector:local` (Phase 1). Produces: `COLLECTOR_IMAGE` as the documented override, used by Phase 5's README text and Phase 7.

Replace the `build:` with the published image and prove a local image still runs through Compose.

- [ ] Add to `spec/image_publishing_spec.rb`, inside `RSpec.describe "Image publishing files"`:
  ```ruby
    describe "compose.yaml" do
      let(:compose) { Rails.root.join("compose.yaml") }
      let(:service) { YAML.load_file(compose).dig("services", "web") }

      it "pulls the published image by default, overridable with COLLECTOR_IMAGE (AC-1.5, FR-4)", :aggregate_failures do
        expect(service["image"]).to eq("${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}")
        expect(service).not_to have_key("build")
        expect(compose.read).to match(/^# Optional: COLLECTOR_IMAGE /)
      end

      it "keeps the rest of the service unchanged (FR-4)", :aggregate_failures do
        expect(service["ports"]).to eq([ "${COLLECTOR_PORT:-3000}:8080" ])
        expect(service["volumes"]).to eq([ "collector_storage:/rails/storage" ])
        expect(service.dig("healthcheck", "test")).to eq([ "CMD", "curl", "-fsS", "http://localhost:8080/up" ])
        expect(service["environment"].keys).to contain_exactly(
          "SECRET_KEY_BASE", "SOLID_QUEUE_IN_PUMA", "HTTP_PORT", "COLLECTOR_MTG_LANGUAGES", "COLLECTOR_CURRENCY",
          "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES")
      end
    end
  ```
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `4 examples, 1 failure` (the published-image example).
- [ ] Edit `compose.yaml`: replace the header's first three lines and the `build:`/`image:` pair:
  ```yaml
  # Self-host Collector with Docker Compose (or podman compose) from the published image.
  # Required: SECRET_KEY_BASE (generate with: openssl rand -hex 64)
  # Optional: COLLECTOR_IMAGE (image to run, default ghcr.io/plainprogrammer/collector:latest;
  #           e.g. collector:local after `docker build -t collector:local .`)
  # Optional: COLLECTOR_PORT (host port, default 3000)
  ```
  (the remaining `# Optional:` lines stay as they are), and under `services: web:`:
  ```yaml
      image: ${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}
  ```
  with the `build: .` line removed. Everything else in the file is unchanged.
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `4 examples, 0 failures`.
- [ ] Prove the override with the local image (AC-1.4). Use a throwaway project name so the worktree's earlier Compose volume is untouched:
  ```sh
  SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)') COLLECTOR_IMAGE=collector:local COLLECTOR_PORT=3012 \
    podman compose -p collector012 up -d
  for i in $(seq 1 30); do curl -fsS http://localhost:3012/up >/dev/null 2>&1 && break; sleep 2; done
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3012/up
  podman compose -p collector012 ps --format '{{.Image}} {{.Status}}'
  podman compose -p collector012 down -v
  ```
  Expected: `200`, and the `ps` line shows `localhost/collector:local` and `Up … (healthy)`.
- [ ] Commit: `feat(compose): run the published image by default, COLLECTOR_IMAGE to override (012)`

---

## Phase 3: Kamal deploys a published release

**Implements:** FR-5 | **Satisfies:** AC-5.1, AC-5.2 (configuration side), AC-5.4
**Files:** `config/deploy.yml`, `spec/image_publishing_spec.rb`
**Interfaces:** Consumes: nothing. Produces: the deploy file Phase 5's README text describes.

Point Kamal at the published image with active registry credentials, and record what `bin/kamal config` prints.

- [ ] Add to `spec/image_publishing_spec.rb`:
  ```ruby
    describe "config/deploy.yml" do
      let(:deploy) { YAML.load_file(Rails.root.join("config/deploy.yml")) }

      it "deploys the published image from GHCR with active credentials (AC-5.1, AC-5.4, FR-5)", :aggregate_failures do
        expect(deploy["image"]).to eq("plainprogrammer/collector")
        expect(deploy["registry"]).to eq("server" => "ghcr.io", "username" => "plainprogrammer",
                                         "password" => [ "KAMAL_REGISTRY_PASSWORD" ])
        expect(deploy.dig("builder", "arch")).to eq("amd64")
        expect(deploy.dig("servers", "web")).to eq([ "192.168.0.1" ])
      end
    end
  ```
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `5 examples, 1 failure`.
- [ ] Edit `config/deploy.yml`:
  ```yaml
  # Name of the container image. Releases are published to GHCR by CI (docs/releasing.md); deploy one with
  # `bin/kamal deploy --skip-push --version X.Y.Z`. To build and push your own image instead, change `image`
  # and `registry` to a registry you own; never run a plain `bin/kamal deploy` against the public image.
  image: plainprogrammer/collector
  ```
  and
  ```yaml
  # Where you keep your container images.
  registry:
    # Alternatives: hub.docker.com / registry.digitalocean.com / localhost:5555 (Kamal starts a local registry) / ...
    server: ghcr.io
    username: plainprogrammer

    # Always use an access token rather than real password when possible. Kamal needs credentials for every
    # registry except localhost, even to pull a public image.
    password:
      - KAMAL_REGISTRY_PASSWORD
  ```
  The `servers:` placeholder and everything else stay.
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `5 examples, 0 failures`.
- [ ] Check the configuration (AC-5.1, AC-5.2):
  ```sh
  bin/kamal config | grep -E "absolute_image|^:?version"
  bin/kamal config --version 0.1.0 | grep -E "absolute_image|^:?version"
  ```
  Expected: `:absolute_image: ghcr.io/plainprogrammer/collector:<git sha>` and `:version: <git sha>` from the first; `:absolute_image: ghcr.io/plainprogrammer/collector:0.1.0` and `:version: 0.1.0` from the second. Paste both outputs into Phase 7's verification notes.
- [ ] Maintainer check for AC-5.4's second half (agents cannot read secret files, and a spec on it would print its contents on failure): the maintainer runs `grep -c KAMAL_REGISTRY_PASSWORD .kamal/secrets` and expects `1`. Record the answer in the commit body.
- [ ] Commit: `feat(deploy): point Kamal at the published GHCR image (012)`

---

## Phase 4: The workflow builds, smoke-tests and publishes

**Implements:** FR-1, FR-2 | **Satisfies:** AC-2.1, AC-2.3, AC-3.1 to AC-3.7, AC-4.1 to AC-4.3 (file shape here; runs in Phases 6 and 7)
**Files:** `.github/workflows/ci.yml`, `spec/image_publishing_spec.rb`
**Interfaces:** Consumes: `bin/image-smoke` (Phase 0). Produces: jobs `ci`, `image`, `publish`; the tag rules Phase 5 documents.

Extend `ci.yml` with the two jobs from ADR 0010, shaped by the file-shape examples below.

- [ ] Verify the action tags exist before pinning:
  ```sh
  for a in docker/setup-buildx-action:v4 docker/login-action:v4 docker/metadata-action:v6 docker/build-push-action:v7 actions/download-artifact:v7; do
    gh api "repos/${a%%:*}/git/refs/tags/${a##*:}" --jq .ref
  done
  ```
  Expected: five `refs/tags/vN` lines. If one is missing, use that action's highest existing major and note it in the commit body.
- [ ] Add to `spec/image_publishing_spec.rb`:
  ```ruby
    describe ".github/workflows/ci.yml" do
      let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ci.yml")) }
      let(:triggers) { workflow[true] || workflow["on"] } # Psych reads the YAML key `on` as true
      let(:image_job) { workflow.dig("jobs", "image") }
      let(:publish_job) { workflow.dig("jobs", "publish") }
      let(:steps) { image_job["steps"] }

      def step(id) = steps.find { |candidate| candidate["id"] == id }

      it "runs on pull requests, pushes to main and release tags only (FR-1, AC-3.6)", :aggregate_failures do
        expect(triggers.keys).to contain_exactly("pull_request", "push")
        expect(triggers.dig("push", "branches")).to eq([ "main" ])
        expect(triggers.dig("push", "tags")).to eq([ "v[0-9]+.[0-9]+.[0-9]+", "v[0-9]+.[0-9]+.[0-9]+-*" ])
      end

      it "builds both architectures natively after bin/ci, then publishes (ADR 0010, FR-1)", :aggregate_failures do
        expect(image_job["needs"]).to eq("ci")
        expect(image_job["runs-on"]).to eq("${{ matrix.runner }}")
        expect(image_job.dig("strategy", "matrix", "include")).to contain_exactly(
          { "platform" => "linux/amd64", "runner" => "ubuntu-latest" },
          { "platform" => "linux/arm64", "runner" => "ubuntu-24.04-arm" })
        expect(publish_job["needs"]).to eq("image")
      end

      it "grants packages: write only to the image and publish jobs (NFR Security)", :aggregate_failures do
        expect(workflow["permissions"]).to eq("contents" => "read")
        expect(image_job["permissions"]).to eq("contents" => "read", "packages" => "write")
        expect(publish_job["permissions"]).to eq("contents" => "read", "packages" => "write")
        expect(workflow.dig("jobs", "ci")).not_to have_key("permissions")
      end

      it "never pushes from a pull request and caches only in Actions (AC-4.2, FR-1)", :aggregate_failures do
        expect(step("push")["if"]).to eq("github.event_name != 'pull_request'")
        expect(publish_job["if"]).to eq("github.event_name != 'pull_request'")
        expect(step("build")["with"]).to include("load" => true)
        expect(step("build")["with"]).not_to have_key("outputs")
        expect(step("build").dig("with", "cache-to")).to start_with("type=gha,")
        expect(step("push").dig("with", "outputs")).to include("push-by-digest=true", "push=true")
        expect(step("push")["with"]).not_to have_key("cache-to")
      end

      it "builds without attestations so a manifest list has two entries (AC-2.1)", :aggregate_failures do
        expect(step("build")["with"]).to include("provenance" => false, "sbom" => false)
        expect(step("push")["with"]).to include("provenance" => false, "sbom" => false)
      end

      it "smoke-tests each image between the build and the push (AC-4.3, AC-6.2)" do
        names = steps.map { |candidate| candidate["id"] || candidate["name"] }
        expect(names.index("Smoke test")).to be_between(names.index("build"), names.index("push")).exclusive
      end

      it "tags releases, main and SHAs per ADR 0009 (FR-2)", :aggregate_failures do
        rules = step("meta").dig("with", "tags").lines(chomp: true)
        expect(rules).to include("type=edge,branch=main", "type=sha,enable=${{ github.ref == 'refs/heads/main' }}")
        expect(rules).to include("type=semver,pattern={{version}}", "type=semver,pattern={{major}}.{{minor}}")
        expect(rules).to include("type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}")
        expect(publish_job["steps"].find { |candidate| candidate["id"] == "meta" }.dig("with", "tags")).to eq(step("meta").dig("with", "tags"))
      end

      it "labels the licence and description explicitly (AC-3.5, FR-2)" do
        expect(step("meta").dig("with", "labels").lines(chomp: true)).to include(
          "org.opencontainers.image.licenses=AGPL-3.0",
          "org.opencontainers.image.description=Self-hostable, multi-tenant web app for tracking collectibles, " \
          "starting with Magic: The Gathering cards.")
      end
    end
  ```
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `13 examples, 8 failures` (every workflow example fails; `image_job` is nil).
- [ ] Replace `.github/workflows/ci.yml` with:
  ```yaml
  name: CI

  on:
    pull_request:
    push:
      branches: [ main ]
      # Release tags only (docs/releasing.md): vX.Y.Z and vX.Y.Z-<pre-release>. Other tags run nothing.
      tags:
        - "v[0-9]+.[0-9]+.[0-9]+"
        - "v[0-9]+.[0-9]+.[0-9]+-*"

  # Only the image and publish jobs may write packages.
  permissions:
    contents: read

  env:
    IMAGE: ghcr.io/plainprogrammer/collector

  jobs:
    ci:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run bin/ci
          run: bin/ci

        - name: Keep screenshots from failed system specs
          uses: actions/upload-artifact@v7
          if: failure()
          with:
            name: screenshots
            path: tmp/capybara
            if-no-files-found: ignore

    # Builds the image natively for each architecture (ADR 0010), smoke-tests it, and on main and release tags
    # pushes it by digest for the publish job to merge. Pull requests build and test but push nothing.
    image:
      name: Image (${{ matrix.platform }})
      needs: ci
      runs-on: ${{ matrix.runner }}
      permissions:
        contents: read
        packages: write
      strategy:
        fail-fast: false
        matrix:
          include:
            - platform: linux/amd64
              runner: ubuntu-latest
            - platform: linux/arm64
              runner: ubuntu-24.04-arm
      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Name the platform for cache and artifact keys
          id: platform
          run: echo "pair=${PLATFORM//\//-}" >> "$GITHUB_OUTPUT"
          env:
            PLATFORM: ${{ matrix.platform }}

        - name: Set up Buildx
          uses: docker/setup-buildx-action@v4

        - name: Log in to GHCR
          if: github.event_name != 'pull_request'
          uses: docker/login-action@v4
          with:
            registry: ghcr.io
            username: ${{ github.actor }}
            password: ${{ secrets.GITHUB_TOKEN }}

        # Tags per ADR 0009: edge and sha-<7 chars> on main; X.Y.Z, X.Y, latest and X (from 1 up) on vX.Y.Z;
        # only X.Y.Z-<pre> on pre-releases. Licence and description are set here, not read from the repository.
        - name: Image tags and labels
          id: meta
          uses: docker/metadata-action@v6
          with:
            images: ${{ env.IMAGE }}
            tags: |
              type=edge,branch=main
              type=sha,enable=${{ github.ref == 'refs/heads/main' }}
              type=semver,pattern={{version}}
              type=semver,pattern={{major}}.{{minor}}
              type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
            labels: |
              org.opencontainers.image.licenses=AGPL-3.0
              org.opencontainers.image.description=Self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards.

        - name: Build
          id: build
          uses: docker/build-push-action@v7
          with:
            context: .
            platforms: ${{ matrix.platform }}
            load: true
            tags: collector:smoke
            labels: ${{ steps.meta.outputs.labels }}
            provenance: false
            sbom: false
            cache-from: type=gha,scope=${{ steps.platform.outputs.pair }}
            cache-to: type=gha,mode=max,scope=${{ steps.platform.outputs.pair }}

        - name: Smoke test
          run: bin/image-smoke collector:smoke

        # Same build from the cache, exported to the registry by digest (untagged) for the publish job.
        - name: Push by digest
          id: push
          if: github.event_name != 'pull_request'
          uses: docker/build-push-action@v7
          with:
            context: .
            platforms: ${{ matrix.platform }}
            labels: ${{ steps.meta.outputs.labels }}
            provenance: false
            sbom: false
            cache-from: type=gha,scope=${{ steps.platform.outputs.pair }}
            outputs: type=image,name=${{ env.IMAGE }},push-by-digest=true,name-canonical=true,push=true

        - name: Save the digest
          if: github.event_name != 'pull_request'
          run: |
            mkdir -p /tmp/digests
            touch "/tmp/digests/${DIGEST#sha256:}"
          env:
            DIGEST: ${{ steps.push.outputs.digest }}

        - name: Upload the digest
          if: github.event_name != 'pull_request'
          uses: actions/upload-artifact@v7
          with:
            name: digest-${{ steps.platform.outputs.pair }}
            path: /tmp/digests/*
            if-no-files-found: error
            retention-days: 1

    # Merges the two digests into one manifest list under the tags from docker/metadata-action, then checks it.
    publish:
      name: Publish manifest list
      needs: image
      if: github.event_name != 'pull_request'
      runs-on: ubuntu-latest
      permissions:
        contents: read
        packages: write
      steps:
        - name: Download the digests
          uses: actions/download-artifact@v7
          with:
            path: /tmp/digests
            pattern: digest-*
            merge-multiple: true

        - name: Set up Buildx
          uses: docker/setup-buildx-action@v4

        - name: Log in to GHCR
          uses: docker/login-action@v4
          with:
            registry: ghcr.io
            username: ${{ github.actor }}
            password: ${{ secrets.GITHUB_TOKEN }}

        - name: Image tags and labels
          id: meta
          uses: docker/metadata-action@v6
          with:
            images: ${{ env.IMAGE }}
            tags: |
              type=edge,branch=main
              type=sha,enable=${{ github.ref == 'refs/heads/main' }}
              type=semver,pattern={{version}}
              type=semver,pattern={{major}}.{{minor}}
              type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
            labels: |
              org.opencontainers.image.licenses=AGPL-3.0
              org.opencontainers.image.description=Self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards.

        - name: Create and push the manifest list
          working-directory: /tmp/digests
          run: |
            docker buildx imagetools create \
              $(jq -cr '.tags | map("-t " + .) | join(" ")' <<< "$DOCKER_METADATA_OUTPUT_JSON") \
              $(printf "$IMAGE@sha256:%s " *)

        # AC-2.1: exactly linux/amd64 and linux/arm64, nothing else.
        - name: Check the manifest list
          run: |
            docker buildx imagetools inspect "$IMAGE:${{ steps.meta.outputs.version }}" --format '{{json .Manifest}}' \
              | jq -e '[.manifests[] | .platform.os + "/" + .platform.architecture] | sort == ["linux/amd64", "linux/arm64"]'
  ```
- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `13 examples, 0 failures`.
- [ ] Sanity-check the YAML and the smoke script's shell:
  ```sh
  ruby -ryaml -e 'puts YAML.load_file(".github/workflows/ci.yml")["jobs"].keys.inspect'
  bash -n bin/image-smoke && echo shell-ok
  ```
  Expected: `["ci", "image", "publish"]`, `shell-ok`.
- [ ] Run `bin/rubocop` — expect: `no offenses detected`.
- [ ] Commit: `ci(image): build, smoke-test and publish multi-architecture images to GHCR (012)`

> **Complexity note.** Gate: Simplicity (≤3 components). The feature has three: the workflow jobs, the smoke script, and the consumer configuration with its docs. Within budget; no new runtime dependency.

---

## Phase 5: Documentation

**Implements:** FR-5 (documentation), FR-6 | **Satisfies:** AC-5.3, AC-7.1, AC-7.2, AC-7.3, AC-7.4
**Files:** `README.md`, `docs/releasing.md` (new), `CLAUDE.md`, `.claude/memory/steering/tech-stack.md`, `.claude/memory/steering/team-practices.md`, `spec/readme_spec.rb`, `spec/image_publishing_spec.rb`
**Interfaces:** Consumes: the tag rules (Phase 4), `COLLECTOR_IMAGE` (Phase 2), the deploy file (Phase 3). Produces: `docs/releasing.md`, which Phase 7 follows step by step.

Write the self-hoster's instructions and the maintainer's release procedure, and fix the sentences this feature makes stale.

- [ ] In `spec/readme_spec.rb`, change the existing upgrade example's expectation and add one example:
  ```ruby
    it "puts the upgrade warning before the upgrade steps" do
      upgrade = readme[/### Upgrading to accounts.*?(?=^## )/m]
      expect(upgrade.index("Read this before you upgrade")).to be < upgrade.index("1. Pull the new image")
    end

    it "documents the published image for Compose and Kamal (spec 012 AC-5.3, AC-7.3, AC-7.4)", :aggregate_failures do
      compose = readme[/^### Docker Compose\n.*?(?=^###)/m].to_s
      expect(compose).to include("COLLECTOR_IMAGE", "ghcr.io/plainprogrammer/collector", "docker compose pull && docker compose up -d",
                                 "docker build -t collector:local .")
      expect(compose).not_to include("--build")
      kamal = readme[/^### Kamal\n.*?(?=^###)/m].to_s
      expect(kamal).to include("bin/kamal deploy --skip-push --version", "a registry you own", "Never run a plain `bin/kamal deploy`")
      expect(readme[/^### Card scanner\n.*?(?=^##)/m].to_s).to include("The published image already contains it")
      expect(readme).to include("docs/releasing.md")
      expect(readme).not_to include("pull the new code")
    end
  ```
- [ ] Add to `spec/image_publishing_spec.rb`:
  ```ruby
    describe "docs/releasing.md" do
      let(:doc) { Rails.root.join("docs/releasing.md").read }

      it "records the release procedure and what each trigger publishes (AC-7.1)", :aggregate_failures do
        expect(doc).to include("git tag -a v", "v0.1.0", "| Tag `vX.Y.Z` |", "| Push to `main` |", "| Pull request |")
        expect(doc).to include("vX.Y.Z-<suffix>", "Only the newest release's workflow may be re-run")
      end

      it "orders the go-public checklist and says it cannot be undone (AC-7.2)", :aggregate_failures do
        positions = [ "Push the first image", "Verify an authenticated pull", "Confirm the package is linked",
                      "Change the visibility to public", "Verify an anonymous pull" ].map { |step| doc.index(step) }
        expect(positions).to all(be_a(Integer))
        expect(positions).to eq(positions.sort)
        expect(doc).to include("cannot be undone")
      end
    end
  ```
- [ ] Run: `bin/rspec spec/readme_spec.rb spec/image_publishing_spec.rb` — expect: 4 failures (the changed upgrade example and the new README example in `readme_spec`; both `docs/releasing.md` examples, which error on the missing file).
- [ ] Edit `README.md`. Under "Testing and CI", replace both lines of the last paragraph (the GitHub Actions sentence and the Dependabot sentence) with:
  ```markdown
  GitHub Actions (`.github/workflows/ci.yml`) runs `bin/ci` first, so local and hosted CI are the same; it then
  builds the container image for amd64 and arm64 and, on `main` and release tags, publishes it (see
  [Self-hosting](#self-hosting) and `docs/releasing.md`). Dependabot keeps gems and GitHub Actions up to date.
  ```
  Replace the Self-hosting introduction's first paragraph:
  ```markdown
  Two deployment paths are supported: Docker Compose for a single machine, and Kamal for
  deploying to your own servers. Both run the published image `ghcr.io/plainprogrammer/collector`
  (built from the `Dockerfile` in this repository for amd64 and arm64) and keep all data in SQLite
  on a persistent volume. `latest` is the newest release; `edge` follows `main`. Releases and their
  tags are described in `docs/releasing.md`.
  ```
  In the Docker Compose subsection: replace the first line with
  ```markdown
  `compose.yaml` works with both `docker compose` and `podman compose`, and needs no checkout: download
  the file and start it.
  ```
  add the variable table row (after `COLLECTOR_PORT`):
  ```markdown
  | `COLLECTOR_IMAGE`           | no       | `ghcr.io/plainprogrammer/collector:latest` | Image to run; set it to a tag such as `ghcr.io/plainprogrammer/collector:0.1` to pin a release, or to a locally built image |
  ```
  replace the **Upgrades** bullet:
  ```markdown
  - **Upgrades:** `docker compose pull && docker compose up -d`. Database migrations run automatically
    when the container starts.
  - **Building from source:** `docker build -t collector:local .` in a checkout, then start Compose with
    `COLLECTOR_IMAGE=collector:local`.
  ```
  Replace the Kamal subsection's numbered steps:
  ```markdown
  1. Edit `config/deploy.yml`: replace the placeholder server (`192.168.0.1`) with your own. The
     registry is already `ghcr.io` with the published image.
  2. Secrets come from `.kamal/secrets`, which reads `RAILS_MASTER_KEY` from `config/master.key`
     and the registry password from the `KAMAL_REGISTRY_PASSWORD` environment variable. Kamal
     needs registry credentials even to pull a public image: use a GitHub token with `read:packages`.
  3. Check the configuration with `bin/kamal config`.
  4. Run `bin/kamal setup --skip-push --version X.Y.Z` for the first deployment, and
     `bin/kamal deploy --skip-push --version X.Y.Z` after that, naming the release to deploy. Kamal
     pulls that tag; nothing is built or pushed.

  To deploy an image you build yourself, change `image` and `registry` in `config/deploy.yml` to
  a registry you own, then run `bin/kamal deploy`. Never run a plain `bin/kamal deploy` with the
  registry set to `ghcr.io/plainprogrammer/collector`: it would push a single-architecture `latest`
  over the published image.
  ```
  In the Card scanner subsection, the sentence "The image build downloads … not from a third party." is wrapped across three lines, starting after "sent to your instance." on the fourth line of the paragraph; replace that wrapped span (keep "sent to your instance." and what precedes it) with:
  ```markdown
  The image build downloads the scanner's OCR engine from `registry.npmjs.org` and checks each file against a pinned
  SHA-256; your instance serves it from `/ocr/v7.0.0/`, so phones fetch it from you, not from a third party.
  The published image already contains it.
  ```
  ("The published image already contains it." stays on one line: `readme_spec` matches it.)
  Replace the "Upgrading to accounts" steps:
  ```markdown
  1. Pull the new image (`docker compose pull`, or pick the release for Kamal).
  2. Run `docker compose up -d` (or `bin/kamal deploy --skip-push --version X.Y.Z`). Migrations run when the container starts.
  3. Create or claim the admin account as described above.
  ```
- [ ] Write `docs/releasing.md`:
  ```markdown
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
  nothing. Every published image carries OCI labels for its source, version, revision, licence and description.

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
  ```
- [ ] Edit `CLAUDE.md`: in Commands, replace the CI bullet's last sentence:
  ```markdown
  - Local CI (single CI definition, `config/ci.rb`): `bin/ci` — setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec. GitHub Actions runs `bin/ci`, then builds the container image for amd64 and arm64 (smoke-tested with `bin/image-smoke`) and publishes it to `ghcr.io/plainprogrammer/collector` on `main` (`edge`) and release tags (spec 012, `docs/releasing.md`). Change CI steps in `config/ci.rb`.
  ```
  and in Non-obvious Facts, replace the Deploy bullet:
  ```markdown
  - **Deploy:** Compose (`compose.yaml`, `image:` defaults to the published `ghcr.io/plainprogrammer/collector:latest`, `COLLECTOR_IMAGE` overrides) and Kamal (`config/deploy.yml`, registry `ghcr.io`, placeholder server; deploy a release with `bin/kamal deploy --skip-push --version X.Y.Z`) both mount the `collector_storage` volume at `/rails/storage` and set `SOLID_QUEUE_IN_PUMA`. Both paths are documented in `README.md`; keep it in sync. `.dockerignore` keeps `docs/`, `spec/`, `spikes/`, `script/` and agent files out of the (public) image.
  ```
- [ ] Edit `.claude/memory/steering/tech-stack.md`: replace the Infrastructure paragraph's first sentence and the CI line:
  ```markdown
  Self-hostable; both paths run the published image `ghcr.io/plainprogrammer/collector` (built by CI from the Rails-generated `Dockerfile` for amd64 and arm64, Thruster in front of Puma, non-root uid 1000, `db:prepare` on boot) and run Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA=true`):
  ```
  with the Compose bullet now saying `image:` defaults to the published `latest` (`COLLECTOR_IMAGE` overrides; no `build:`) and the Kamal bullet saying registry `ghcr.io`, deploy by `--skip-push --version`; and
  ```markdown
  - CI: GitHub Actions runs `bin/ci`, then builds, smoke-tests and (on `main` and `vX.Y.Z` tags) publishes the image; Dependabot for bundler and github-actions. Releases: `docs/releasing.md`.
  ```
- [ ] Edit `.claude/memory/steering/team-practices.md`, Release Process:
  ```markdown
  ## Release Process
  Tag `main` with an annotated `vX.Y.Z` tag; CI publishes the image (`docs/releasing.md`). Migrations are safe to run from any prior version; breaking changes ship with upgrade notes in the README.
  ```
- [ ] Run: `bin/rspec spec/readme_spec.rb spec/image_publishing_spec.rb` — expect: `0 failures`.
- [ ] Run `bin/rubocop` — expect: `no offenses detected`.
- [ ] Commit: `docs(deploy): document the published image, releasing and going public (012)`

---

## Phase 6: Integration verification on the pull request

**Implements:** FR-1 | **Satisfies:** AC-4.2, AC-4.3, NFR Performance (pull-request run)
**Files:** none (evidence only)
**Interfaces:** Consumes: everything above. Produces: the run URL and durations for the verification notes.

Push the branch, open the pull request, and read the run.

- [ ] Run the full gate locally: `bin/ci` — expect: every step green (the pre-push hook runs it again).
- [ ] Push and open the PR:
  ```sh
  git push -u origin 012-ghcr-registry-publishing
  gh pr create --title "Build and publish Collector images to GHCR (012)" --body-file - <<'EOF'
  Spec 012: CI builds the image natively for amd64 and arm64, smoke-tests it, and publishes `ghcr.io/plainprogrammer/collector` on `main` (`edge`) and `vX.Y.Z` tags. Compose and Kamal run the published image. `docs/releasing.md` has the release procedure and the one-time go-public checklist.

  Verification: this PR's run must show `ci`, `Image (linux/amd64)`, `Image (linux/arm64)` green and `Publish manifest list` skipped.

  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  https://claude.ai/code/session_01EwMtjviQnh5BJeChaSWF1B
  EOF
  ```
- [ ] Watch the run: `gh run watch` (pick the PR's run) — expect: `ci` ✓, `Image (linux/amd64)` ✓, `Image (linux/arm64)` ✓, `Publish manifest list` skipped.
- [ ] Record the durations and confirm nothing was pushed:
  ```sh
  gh run view --json jobs --jq '.jobs[] | "\(.name) \(.conclusion) \(.startedAt) \(.completedAt)"'
  gh api /user/packages/container/collector 2>&1 | head -1
  ```
  Expected: the run under 30 minutes end to end; the package request answers `404` (no package exists yet).
- [ ] If `Image (linux/arm64)` fails to start because the runner label is unavailable to the private repository, apply ADR 0010's fallback in a `ci(image): build arm64 under QEMU` commit: set that matrix entry's `runner` to `ubuntu-latest`, add a step before "Set up Buildx":
  ```yaml
        - name: Set up QEMU
          if: matrix.platform == 'linux/arm64'
          uses: docker/setup-qemu-action@v4
  ```
  update the matrix expectation in `spec/image_publishing_spec.rb` to match, and note the change in the verification notes. Tags and the merge job do not change.
- [ ] If a smoke step fails on a runner, read its log (`gh run view --log-failed`), fix the cause (the script's expectation or the image), and push; do not skip the step.
- [ ] Request the maintainer's review of the PR. Merge only with their approval.

---

## Phase 7: First publish, going public, and the first release (after the merge)

**Implements:** All FRs | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-2.1, AC-2.2, AC-2.3 (by construction), AC-3.1, AC-3.3 (deferred to the first pre-release), AC-3.4, AC-3.5, AC-3.6, AC-3.7, AC-4.1, AC-5.2, AC-7.2
**Files:** `docs/specs/012-ghcr-registry-publishing/verification.md` (new, committed on `main` afterwards as `docs(specs): record the first publish of spec 012`)
**Interfaces:** Consumes: `docs/releasing.md` (Phase 5). Produces: the verification notes.

Follow `docs/releasing.md` for the first time, with the extra checks the spec asks for, and record every output.

- [ ] After the merge, watch the `main` run: `gh run watch` — expect: `Publish manifest list` green. Record the duration, noting that the Actions cache is branch-scoped: this first `main` run builds cold; later `main` and pull-request runs reuse `main`'s cache.
- [ ] AC-4.1: `gh api /user/packages/container/collector/versions --jq '.[].metadata.container.tags'` — expect: `["edge","sha-<7 chars>"]` on one version, and `latest` absent.
- [ ] Go-public steps 1 to 5 from `docs/releasing.md`, each with its output: `visibility` prints `private`; the authenticated pull and `bin/image-smoke …:edge` pass; the package page shows the repository, the description and the licence; the visibility change is made in the browser; after `podman logout ghcr.io`, the anonymous pull succeeds (AC-1.1 on `edge`; `latest` is re-checked below).
- [ ] AC-3.6: push an off-pattern tag and confirm no run starts, then delete it:
  ```sh
  git tag v0.1 && git push origin v0.1
  sleep 60; gh run list --limit 3 --json headBranch,event,status --jq '.[] | "\(.event) \(.headBranch) \(.status)"'
  git push --delete origin v0.1 && git tag -d v0.1
  ```
  Expected: no run with `headBranch` `v0.1`.
- [ ] Cut `v0.1.0` per `docs/releasing.md`. Watch the run; expect `Publish manifest list` green and the "Check the manifest list" step passing.
- [ ] AC-3.1, AC-2.1, AC-3.5, AC-1.1 on `latest`:
  ```sh
  gh api /user/packages/container/collector/versions --jq '.[].metadata.container.tags'
  podman pull ghcr.io/plainprogrammer/collector:latest
  podman manifest inspect ghcr.io/plainprogrammer/collector:latest | jq '[.manifests[] | .platform.os + "/" + .platform.architecture]'
  podman inspect ghcr.io/plainprogrammer/collector:latest --format '{{json .Labels}}' | jq .
  ```
  Expected: one version tagged `["0.1.0","0.1","latest"]` with no `0`; the manifest array is exactly `["linux/amd64","linux/arm64"]`; labels show `org.opencontainers.image.source` = `https://github.com/plainprogrammer/Collector`, `.version` = `0.1.0`, `.revision` = the tagged commit, `.licenses` = `AGPL-3.0`, `.description` = the sentence from the spec. Also `podman inspect …:edge` shows `.version` = `edge`.
- [ ] AC-1.2 and AC-1.3 (upgrade keeps data). Start from `edge`, create a user, switch to `latest`:
  ```sh
  export SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)') COLLECTOR_PORT=3012
  COLLECTOR_IMAGE=ghcr.io/plainprogrammer/collector:edge podman compose -p collector012 up -d
  for i in $(seq 1 30); do curl -fsS http://localhost:3012/up >/dev/null 2>&1 && break; sleep 2; done
  podman compose -p collector012 exec -e COLLECTOR_PASSWORD='upgrade-check-1234' web bin/rails "collector:user[upgrade@example.com]"
  podman compose -p collector012 pull && podman compose -p collector012 up -d
  for i in $(seq 1 30); do curl -fsS http://localhost:3012/up >/dev/null 2>&1 && break; sleep 2; done
  podman compose -p collector012 ps --format '{{.Image}} {{.Status}}'
  podman compose -p collector012 exec web bin/rails runner 'puts User.exists?(email_address: "upgrade@example.com")'
  ```
  Expected: `Created admin upgrade@example.com.`; after the pull the `ps` line shows `…collector:latest` and `(healthy)`; `true`. Then sign in at `http://localhost:3012` as that user and open `/scanner` (AC-6.2's signed-in check). Finally `podman compose -p collector012 down -v`.
- [ ] AC-2.2 (arm64), emulated on the development machine:
  ```sh
  podman pull --platform linux/arm64 ghcr.io/plainprogrammer/collector:latest
  SMOKE_BOOT_ATTEMPTS=300 bin/image-smoke ghcr.io/plainprogrammer/collector:latest --platform linux/arm64
  ```
  Expected: `OK: … passed the smoke test` (slow under emulation; the boot may take minutes, hence 300 attempts).
- [ ] AC-5.2: `bin/kamal config --version 0.1.0 | grep -E "absolute_image|version"` — expect `:absolute_image: ghcr.io/plainprogrammer/collector:0.1.0` and `:version: 0.1.0`. A live deploy is the maintainer's check.
- [ ] AC-3.7: re-run the `v0.1.0` workflow (`gh run rerun <id>`), then repeat the `versions`, `manifest inspect` and `inspect … Labels` commands: the same three tags, two platforms, identical `.version` and `.revision`; `edge` and `sha-*` unchanged.
- [ ] Write `docs/specs/012-ghcr-registry-publishing/verification.md` with every command above and its output, the run URLs and durations (PR, `main`, `v0.1.0`, the re-run), the image sizes from Phase 1, and the `bin/kamal config` outputs from Phase 3. Commit it on `main` (or a one-commit PR): `docs(specs): record the first publish of spec 012`.

---

## Phase 8: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bin/ci` on the merged `main` — expect: green.
- [ ] Walk the spec's acceptance criteria against `verification.md`: every AC-N.M has a command and its output, except AC-3.3 (first pre-release, deferred until one is cut) and AC-5.2's live deploy (the maintainer's).
- [ ] Run `sdd-superpowers:sdd-review` (Mode B) with `verification.md` as the evidence.

---

## Quickstart Validation

```sh
# A self-hoster, on a machine with Podman or Docker and nothing else:
curl -fsSLO https://raw.githubusercontent.com/plainprogrammer/Collector/main/compose.yaml   # once the repo is public; until then, copy the file
SECRET_KEY_BASE=$(openssl rand -hex 64) podman compose up -d
curl -fsS http://localhost:3000/up            # 200
# Upgrade later:
podman compose pull && podman compose up -d
```

---

## Coverage map (self-review)

| Spec item | Phase |
|---|---|
| FR-1 triggers and gate | 4 (shape), 6 (PR run), 7 (`main`, tag, off-pattern tag) |
| FR-2 tags and labels | 4 (shape), 7 (AC-3.1, AC-3.5, AC-4.1) |
| FR-3 image contents | 0, 1 |
| FR-4 Compose | 2, 5 (README), 7 (AC-1.1 to AC-1.3) |
| FR-5 Kamal | 3, 5 (README) |
| FR-6 documentation | 5 |
| AC-1.1, 1.2, 1.3 | 7 |
| AC-1.4, 1.5 | 2 |
| AC-2.1 | 4 (workflow check step), 7 |
| AC-2.2 | 7 (emulated) |
| AC-2.3 | 4 (publish needs both image jobs; `fail-fast: false` keeps the other build's log) |
| AC-3.1, 3.2 (rule), 3.4 (gate by `needs`), 3.5, 3.6, 3.7 | 4, 7 |
| AC-3.3 | 4 (rule); first pre-release |
| AC-4.1 | 7 |
| AC-4.2, 4.3 | 4, 6 |
| AC-5.1, 5.4 | 3 |
| AC-5.2 | 3, 7 (config); live deploy: maintainer |
| AC-5.3, 7.3, 7.4 | 5 |
| AC-6.1 to 6.4 | 0, 1 (and every CI run via the smoke step) |
| AC-7.1, 7.2 | 5, 7 |
| NFR Performance | 6, 7 (durations recorded) |
| NFR Security | 4 (permissions, no secrets: smoke hygiene check) |
| NFR Reliability | 4 (`needs`, `if`), 7 (re-run) |
