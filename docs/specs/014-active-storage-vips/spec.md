# Feature 014: Active Storage Variants with vips

**Status:** Approved
**Version:** 1.0.0
**Created:** 2026-10-09
**Last Updated:** 2026-10-09
**Branch:** `014-active-storage-vips`
**Issue:** [#18](https://github.com/plainprogrammer/Collector/issues/18)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-09 | Initial draft from the approved [prd.md](prd.md) and ADR [0013](../../adr/0013-active-storage-variants-with-vips.md) (libvips through `ruby-vips`, not auto-required). Approved by the maintainer |

---

## Problem Statement

Every Rails command run in the published container image logs "Generating image variants with libvips requires the ruby-vips gem". That includes server boot, `catalog:status`, `collector:user` and the smoke test. Vips is the variant processor (`config.load_defaults 8.1`) and the image installs libvips, but the bundle has no `ruby-vips`, so Active Storage can't load its vips transformer.

Self-hosters see what looks like a fault on every command. Maintainers filter the line out of the image's output when comparing results (spec 011 `research.md` §2). And variants wouldn't work if a feature used them: the maintainer expects user-uploaded images for comics and other collectible types, and perhaps for slabbed or graded cards.

> **Inputs.** Scope and decisions come from the approved [prd.md](prd.md) and the accepted [ADR 0013](../../adr/0013-active-storage-variants-with-vips.md). Active Storage, libvips, the `ruby-vips` gem and the existing files this touches are fixed inputs, so this spec names them.
>
> **Terms.**
> - *The vips warnings* are the two lines Active Storage logs when it can't load its vips transformer: one containing "requires the ruby-vips gem", the other "requires the libvips library".
> - *libvips is available* when `ruby-vips` loads in the app's bundle. It does not mean that a `vips` command exists: Fedora's `vips` package ships the library, but the command is in `vips-tools`.
> - *The vips transformer* is `ActiveStorage::Transformers::Vips`, the value of `ActiveStorage.variant_transformer` once Active Storage has loaded it.

## Goals

- Rails commands in the production image log neither of the vips warnings.
- Active Storage variants work with libvips in production, development and CI.
- Development mirrors production: `bin/setup` reports when libvips isn't available, and CI installs it.
- The app still boots where libvips isn't available.
- `bin/image-smoke` and the test suite catch a regression.

## Non-Goals

- Any upload feature: attachments, `active_storage_*` tables, upload validation, thumbnails in a view.
- Re-enabling any of the libvips loaders that `Vips.block_untrusted` blocks.
- Removing ImageMagick or changing the art decoder ([ADR 0012](../../adr/0012-decode-art-images-with-imagemagick.md)).
- Removing Active Storage, Action Text or Action Mailbox.
- Shrinking the image or changing its packages.

## Users and Context

**Primary users:** self-hosters running the published image (Compose or Kamal), who read its logs.
**Secondary users:** the maintainer and agents, who run Rails tasks in the image to verify releases (spec 012) and art builds (spec 011), and who set up development machines and worktrees with `bin/setup`. Later, whoever builds the first upload feature, who needs working variants.
**Usage context:** container boot and `bin/rails` commands in the image; `bin/setup` and `bin/ci` on a development machine; the GitHub Actions `ci.yml` workflow.
**User mental model:** "a clean install logs no warnings, and image variants just work."

**What this touches:**
- `Gemfile` and `Gemfile.lock`.
- `bin/setup`'s dependency checks.
- `.github/workflows/ci.yml`, whose test job installs system packages.
- `bin/image-smoke`.
- `README.md`'s Requirements.
- A new spec and a small image fixture under `spec/`.

The `Dockerfile` already installs libvips in both stages and doesn't change.

## User Stories

### Story 1: The image logs no vips warnings

**As a** self-hoster
**I want** Rails commands in the image to run without a vips warning
**So that** a healthy install doesn't look broken

**Acceptance criteria:**

- [ ] **AC-1.1** Given the built production image When `bin/rails runner` runs a command in it Then the combined output contains neither of the vips warnings.
- [ ] **AC-1.2** Given the built production image When `bin/rails runner` prints `ActiveStorage.variant_transformer` Then it prints `ActiveStorage::Transformers::Vips`.
- [ ] **AC-1.3** Given the image built for `linux/amd64` and the one built for `linux/arm64` When `bin/image-smoke` runs against each (as `ci.yml` does) Then it checks AC-1.1 and AC-1.2 and passes.
- [ ] **AC-1.4** Given an image whose bundle lacks `ruby-vips` (for example, the image built from `main` before this feature) When `bin/image-smoke` runs against it Then it fails, and the failure names the vips check.

### Story 2: Variants work

**As the** developer of a future upload feature
**I want** Active Storage's vips transformer to produce variants
**So that** I can build on it without first fixing the toolchain

**Acceptance criteria:**

- [ ] **AC-2.1** Given a small image fixture under `spec/fixtures/` (for example, a 40×20 PNG) When the test suite runs `ActiveStorage.variant_transformer` with `resize_to_limit: [10, 10]` on it, with no blob and no database tables Then the output is an image of 10×5 pixels.
- [ ] **AC-2.2** Given the test environment When the suite checks `ActiveStorage.variant_transformer` Then it is the vips transformer.
- [ ] **AC-2.3** Given a run of the `ci.yml` workflow When its test job runs `bin/ci` Then libvips is installed before the suite starts, and AC-2.1 and AC-2.2 pass.
- [ ] **AC-2.4** Given a development machine where libvips is available When `bin/ci` runs Then AC-2.1 and AC-2.2 pass.

### Story 3: Development mirrors production, and boot doesn't depend on libvips

**As the** maintainer or an agent setting up a checkout
**I want** `bin/setup` to tell me when libvips is missing, and the app to boot anyway
**So that** a missing library is obvious but never blocks work that doesn't need it

**Acceptance criteria:**

- [ ] **AC-3.1** Given a machine where libvips is available When `bin/setup --skip-server` runs Then it prints no libvips hint and completes.
- [ ] **AC-3.2** Given a machine where libvips isn't available When `bin/setup --skip-server` runs Then it prints a hint naming libvips and the install commands for Fedora (`sudo dnf install vips`) and Debian/Ubuntu, then carries on and completes.
- [ ] **AC-3.3** Given the bundle When Rails boots Then `Bundler.require` doesn't load `ruby-vips`: its Gemfile entry is not auto-required, and a spec asserts this from Bundler's dependency list.
- [ ] **AC-3.4** Given `bin/setup`'s libvips check When it decides whether libvips is available Then it uses the definition in Terms (whether `ruby-vips` loads in the bundle), not whether a `vips` command exists.

### Story 4: Requirements are documented

**As a** contributor setting up from source
**I want** the README to list the system libraries the app needs
**So that** I can install them before running `bin/setup`

**Acceptance criteria:**

- [ ] **AC-4.1** Given `README.md`'s Requirements section When it is read Then it lists libvips (for Active Storage image variants) and ImageMagick (for the card scanner's art index build, ADR 0012), with the Fedora and Debian/Ubuntu package names.

## Functional Requirements

### FR-1: Bundle

**Must:**
- Add `ruby-vips` with the constraint `~> 2.3` and `require: false`, and commit the resulting `Gemfile.lock`. The lock resolves `ffi` for every platform it already lists, at least `x86_64-linux-gnu` and `aarch64-linux-gnu`, which the amd64 and arm64 images use.
- Keep `image_processing` (`~> 2.2`) and the `load_defaults` variant processor (`:vips`).

**Must not:**
- Set `config.active_storage.variant_processor` explicitly.
- Add `mini_magick` or change how art images are decoded.

### FR-2: Image check

**Must:**
- Extend `bin/image-smoke` with one `bin/rails runner` call in the running container that prints `ActiveStorage.variant_transformer`. The check fails when the combined output contains either of the vips warnings or when the printed transformer isn't `ActiveStorage::Transformers::Vips`.

**Must not:**
- Change the `Dockerfile`'s packages.

### FR-3: Development and CI

**Must:**
- Add a libvips check to `bin/setup` beside its ImageMagick check. It prints a hint when libvips isn't available and never fails the setup run.
- Install libvips in `ci.yml`'s test job, in the step that installs ImageMagick. The exact Ubuntu package name is confirmed in the plan.
- Add the variant spec (AC-2.1, AC-2.2) and the bundle spec (AC-3.3) to the suite that `bin/ci` runs, with a committed image fixture of a few hundred bytes.

**Must not:**
- Skip or tag out the variant spec when libvips is missing. It fails, so a misconfigured CI or machine shows up.

### FR-4: Docs

**Must:**
- Update `README.md`'s Requirements (AC-4.1).
- Close issue #18 with the change, and remove the ruby-vips item from the spec 012 follow-ups memory once it merges.

## Non-Functional Requirements

- **Security:** variants keep Active Storage's default `Vips.block_untrusted(true)`. Nothing re-enables blocked loaders. Active Storage raises at boot if libvips is older than 8.13, and every target is newer: the image has 8.16.1, the development machine 8.18.3 and Ubuntu 24.04 8.15.1.
- **Portability:** the image still builds and passes `bin/image-smoke` on both `linux/amd64` and `linux/arm64` (spec 012, ADR 0010).
- **Image size:** the image grows by at most the `ruby-vips` and `ffi` gems (under 1 MB, per spec 008 `research.md` §7).
- **Boot:** the app boots where libvips isn't available. Active Storage then logs the "requires the libvips library" warning, which is expected in that case.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| libvips isn't available on a development machine | Rails boots and logs the "requires the libvips library" warning. `bin/setup` prints its hint and completes. The variant spec fails. |
| libvips isn't installed in CI (a broken install step) | The test job fails: the install step fails, or the variant spec does. |
| A future image drops `ruby-vips` or libvips | `bin/image-smoke` fails on the vips check (AC-1.4), so the image isn't published. |
| libvips older than 8.13 | Active Storage raises at boot. No target has one, and the spec doesn't guard against it. |

## Open Questions

None. The CI package name (`libvips42t64` on Ubuntu 24.04, or a name that resolves to it) is a planning detail. FR-3 leaves it to the plan.

## Out of Scope

- Disabling variants and dropping libvips to shrink the image (ADR 0013, Option B).
- ImageMagick for variants through `mini_magick` (ADR 0013, Option C).
- Upload validation and loader policy for user uploads, which the first upload feature owes (ADR 0013, Consequences).
- Tightening the smoke check's `catalog:status` grep ([#19](https://github.com/plainprogrammer/Collector/issues/19)).
