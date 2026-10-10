# Feature 014: Active Storage Variants with vips

**Status:** Approved
**Version:** 1.1.1
**Created:** 2026-10-09
**Last Updated:** 2026-10-09
**Branch:** `014-active-storage-vips`
**Issue:** [#18](https://github.com/plainprogrammer/Collector/issues/18)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-09 | Initial draft from the approved [prd.md](prd.md) and ADR [0013](../../adr/0013-active-storage-variants-with-vips.md) (libvips through `ruby-vips`, not auto-required). Approved by the maintainer |
| 1.1.0 | 2026-10-09 | Spec review revisions (Fable, Mode A). **Testability** NFR: which ACs are suite examples, which are file-shape specs and which are evidence in `verification.md`. **AC-1.4** names a pinned image (`0.1.0`), since `edge` moves. **libvips check** extracted to `Collector::LibvipsCheck` in `lib/collector/` with an injectable probe (maintainer's choice), probing with `bundle exec ruby -e 'require "ruby-vips"'` because `bin/setup` doesn't run under Bundler (AC-3.1, AC-3.2, AC-3.4, FR-3). **Debian/Ubuntu package** named the same in the hint, README and `ci.yml` (AC-3.2, AC-4.1). **Fixture** under `spec/fixtures/files/`; dimensions read inside the transformer's block (AC-2.1). Closing #18 and memory housekeeping moved from FR-4 to Delivery. Second pass (READY TO PLAN): the fixture may be committed or generated; AC-3.5's two sentences are tagged by how they're checked |
| 1.1.1 | 2026-10-09 | PATCH, from the verification run. **Image size** NFR: the two gems measure about 2.7 MB in the built image (`ruby-vips` 2.3.0 644 KB, `ffi` 1.17.4 2,056 KB), not "under 1 MB". The maintainer accepts the growth. No behaviour changes |

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
- A new class `Collector::LibvipsCheck` in `lib/collector/libvips_check.rb`, which `bin/setup` uses (`require_relative`, like `WorktreeSetup`).
- New specs (the variant, the bundle entry, the libvips check) and, if committed rather than generated, a small image fixture under `spec/fixtures/files/`.

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
- [ ] **AC-1.4** Given the published image `ghcr.io/plainprogrammer/collector:0.1.0`, whose bundle lacks `ruby-vips` When the new `bin/image-smoke` runs against it Then it fails, and the failure names the vips check.

### Story 2: Variants work

**As the** developer of a future upload feature
**I want** Active Storage's vips transformer to produce variants
**So that** I can build on it without first fixing the toolchain

**Acceptance criteria:**

- [ ] **AC-2.1** Given a 40×20 PNG (a committed fixture under `spec/fixtures/files/`, or one generated with `PngHelpers#png_bytes`) When the test suite runs `ActiveStorage.variant_transformer.new(resize_to_limit: [10, 10]).transform(file, format: "png")`, with no blob and no database tables Then the output is a 10×5 image. The dimensions are read inside the block, because the transformer deletes its output file afterwards.
- [ ] **AC-2.2** Given the test environment When the suite checks `ActiveStorage.variant_transformer` Then it is the vips transformer.
- [ ] **AC-2.3** Given a run of the `ci.yml` workflow When its test job runs `bin/ci` Then libvips is installed before the suite starts, and AC-2.1 and AC-2.2 pass.
- [ ] **AC-2.4** Given a development machine where libvips is available When `bin/ci` runs Then AC-2.1 and AC-2.2 pass.

### Story 3: Development mirrors production, and boot doesn't depend on libvips

**As the** maintainer or an agent setting up a checkout
**I want** `bin/setup` to tell me when libvips is missing, and the app to boot anyway
**So that** a missing library is obvious but never blocks work that doesn't need it

**Acceptance criteria:**

- [ ] **AC-3.1** Given the libvips check with a probe that succeeds When it runs Then it reports nothing.
- [ ] **AC-3.2** Given the libvips check with a probe that fails (whether by a non-zero exit or by raising) When it runs Then it reports one hint naming libvips, the Fedora package (`sudo dnf install vips`) and the Debian/Ubuntu package that `ci.yml` installs, and it does not raise.
- [ ] **AC-3.3** Given the bundle When Rails boots Then `Bundler.require` doesn't load `ruby-vips`: its Gemfile entry is not auto-required, and a spec asserts this from Bundler's dependency list.
- [ ] **AC-3.4** Given the libvips check's default probe When it decides whether libvips is available Then it runs `bundle exec ruby -e 'require "ruby-vips"'` with its output discarded and uses the exit status (the definition in Terms). It doesn't look for a `vips` command, and it doesn't `require` the gem in `bin/setup`'s own process, which isn't under Bundler and could load a copy of the gem from outside the bundle.
- [ ] **AC-3.5** Given `bin/setup` When it reaches its dependency checks Then it runs the libvips check beside the ImageMagick check, prints any hint, and carries on whatever the result (file-shape spec). On this development machine, which has libvips, `bin/setup --skip-server` prints no libvips hint (evidence).

### Story 4: Requirements are documented

**As a** contributor setting up from source
**I want** the README to list the system libraries the app needs
**So that** I can install them before running `bin/setup`

**Acceptance criteria:**

- [ ] **AC-4.1** Given `README.md`'s Requirements section When it is read Then it lists libvips (for Active Storage image variants) and ImageMagick (for the card scanner's art index build, ADR 0012), with the Fedora package names and the Debian/Ubuntu package names that `ci.yml` installs.

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
- Add `Collector::LibvipsCheck` (`lib/collector/libvips_check.rb`), with a probe passed in (default: AC-3.4's command) and the hint of AC-3.2. The file loads without side effects. `bin/setup` uses it beside its ImageMagick check (AC-3.5), and a missing libvips never fails the setup run.
- Install libvips in `ci.yml`'s test job, in the step that installs ImageMagick, before `bin/ci`. The plan confirms the exact Ubuntu package name (`libvips42t64` on 24.04, or a name that resolves to it), and the hint (AC-3.2) and README (AC-4.1) use the same name.
- Add the variant spec (AC-2.1, AC-2.2), the bundle spec (AC-3.3) and the libvips check spec (AC-3.1, AC-3.2, AC-3.4) to the suite that `bin/ci` runs. The image fixture is a few hundred bytes, either committed or generated with `spec/support/png_helpers.rb`.

**Must not:**
- Skip or tag out the variant spec when libvips is missing. It fails, so a misconfigured CI or machine shows up.

### FR-4: Docs

**Must:**
- Update `README.md`'s Requirements (AC-4.1).

## Non-Functional Requirements

- **Testability:** AC-2.1, AC-2.2, AC-3.1–AC-3.4 and AC-4.1 are suite examples run by `bin/ci`. The `ci.yml` install step (it names libvips and precedes `bin/ci`), `bin/image-smoke`'s vips check and `bin/setup`'s use of the check (AC-3.5) are also file-shape specs, in the style of `spec/image_publishing_spec.rb`. AC-1.1–AC-1.4, AC-2.3, AC-2.4 and AC-3.5's run on this machine are evidence, recorded in `verification.md`: a local `bin/image-smoke` run on the new image (amd64), the same against `0.1.0` (AC-1.4), this PR's workflow run (both architectures, AC-1.3, AC-2.3), and the output of `bin/ci` and `bin/setup --skip-server`.
- **Security:** variants keep Active Storage's default `Vips.block_untrusted(true)`. Nothing re-enables blocked loaders. Active Storage raises at boot if libvips is older than 8.13, and every target is newer: the image has 8.16.1, the development machine 8.18.3 and Ubuntu 24.04 8.15.1.
- **Portability:** the image still builds and passes `bin/image-smoke` on both `linux/amd64` and `linux/arm64` (spec 012, ADR 0010).
- **Image size:** the image grows by at most the `ruby-vips` and `ffi` gems: about 2.7 MB, measured in the built amd64 image (`ruby-vips` 2.3.0 644 KB, `ffi` 1.17.4 2,056 KB; see `verification.md`). Spec 008 `research.md` §7 estimated under 1 MB.
- **Boot:** the app boots where libvips isn't available. Active Storage then logs the "requires the libvips library" warning, which is expected in that case.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| libvips isn't available on a development machine | Rails boots and logs the "requires the libvips library" warning. `bin/setup` prints its hint and completes. The variant spec fails. |
| The libvips probe can't run (the command is missing, or an injected probe raises) | The check treats that as unavailable, prints the hint, and doesn't raise (AC-3.2). Through `bin/setup` this can't happen in practice, because `bundle check`/`bundle install` run first. |
| libvips isn't installed in CI (a broken install step) | The test job fails: the install step fails, or the variant spec does. |
| A future image drops `ruby-vips` or libvips | `bin/image-smoke` fails on the vips check (AC-1.4), so the image isn't published. |
| libvips older than 8.13 | Active Storage raises at boot. No target has one, and the spec doesn't guard against it. |

## Open Questions

None. The CI package name (`libvips42t64` on Ubuntu 24.04, or a name that resolves to it) is a planning detail. FR-3 leaves it to the plan.

## Out of Scope

**Delivery (not requirements):** the PR closes issue #18. After it merges, the ruby-vips item comes out of `.claude/memory/spec-012-followups.md`, and `.claude/memory/dev-machine-image-tools.md` is corrected: this machine now has libvips 8.18.3, and the lock has `image_processing` 2.2.0.

- Disabling variants and dropping libvips to shrink the image (ADR 0013, Option B).
- ImageMagick for variants through `mini_magick` (ADR 0013, Option C).
- Upload validation and loader policy for user uploads, which the first upload feature owes (ADR 0013, Consequences).
- Tightening the smoke check's `catalog:status` grep ([#19](https://github.com/plainprogrammer/Collector/issues/19)).
