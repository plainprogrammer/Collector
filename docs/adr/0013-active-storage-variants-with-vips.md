# 0013: Process Active Storage variants with libvips through `ruby-vips`

## Status

Accepted (2026-10-09, approved with spec 014's PRD).

**Date:** 2026-10-09
**Feature:** 014-active-storage-vips

## Context

Every Rails command in the production image logs "Generating image variants with libvips requires the ruby-vips gem" ([issue #18](https://github.com/plainprogrammer/Collector/issues/18); spec 012's `verification.md`, spec 011's `research.md` §2). The cause:

- `config.load_defaults 8.1` sets `config.active_storage.variant_processor = :vips`. At boot, Active Storage's engine loads its vips transformer, which requires `ruby-vips`. It rescues the `LoadError` and logs the warning (`activestorage-8.1.4/lib/active_storage/engine.rb`).
- The bundle has `image_processing` 2.2.0 but not `ruby-vips`. The `Dockerfile` (Rails' default) installs `libvips` in both its stages.
- Nothing in the app uses Active Storage yet: there are no attachments and no `active_storage_*` tables. The only image work is the art index build, which decodes with ImageMagick's command line ([ADR 0012](0012-decode-art-images-with-imagemagick.md)).

Variants will be needed later. The maintainer expects user-uploaded images for comics and other collectible types, and perhaps for slabbed or graded cards (2026-10-09). Those images come from users, so they are untrusted input and can be large scans.

What the project has measured (spec 008 [research.md](../specs/008-card-scanner-phase-2-spike/research.md) §7, on the app's `ruby:4.0.7-slim` base): `libvips` is 122 packages, 130,647 KiB installed; `imagemagick` alone is 44 packages, 43,364 KiB; `ruby-vips` 2.3.0 is a 74,240-byte gem plus `ffi` 1.17.4, a native extension with prebuilt platform gems. The development machine now has libvips 8.18.3, and `ruby-vips` 2.3.0 loads against it (2026-10-09).

## Options considered

### Option A: libvips through `ruby-vips` (Rails' default)

**Pros:**
- It is Rails' default processor, so Active Storage's documentation and defaults apply unchanged.
- It is fast and streams images, so memory stays low on large scans. It also has a better record with untrusted input than ImageMagick.
- libvips is already in the image. This adds only `ruby-vips` and `ffi`.

**Cons:**
- The image keeps libvips (about 130 MB installed) for a feature that doesn't exist yet, beside ImageMagick for art decoding: two image toolkits.
- Developers and CI need libvips. Without it, `require "ruby-vips"` fails, so the gem must be `require: false`, or Rails won't boot where libvips is missing.

### Option B: Disable variants and drop libvips until a feature needs them

**Pros:**
- The smallest image (about 90 MB less) and no new gems.
- Fully reversible: no data or migration depends on the processor.

**Cons:**
- Every self-hoster pulls a different image again when variants arrive, and that feature's spec has to reopen this choice.
- Variants don't work in the meantime.

### Option C: ImageMagick through `mini_magick`

**Pros:**
- One image toolkit: ImageMagick is already installed for art decoding, so libvips can go.

**Cons:**
- ImageMagick has the worse record with untrusted input (e.g. ImageTragick) and would need a restrictive `policy.xml` for uploads.
- It is slower and uses more memory than libvips on large images.
- It moves away from Rails' default.

## Decision

**Option A.** Variants will process untrusted, possibly large uploads, and libvips is the better fit for those (speed, memory, and its record with untrusted input). The maintainer chose to commit to it now rather than defer (2026-10-09).

- The `Gemfile` adds `gem "ruby-vips", "~> 2.3", require: false`. Active Storage requires it when it loads the transformer, so environments without libvips still boot.
- The `Dockerfile` keeps `libvips` in both stages. `bin/setup` checks that `ruby-vips` loads (beside its ImageMagick check), and CI installs libvips.
- `config.active_storage.variant_processor` stays at the `load_defaults` value (`:vips`).

Option B is rejected because the maintainer expects uploads and prefers the processor settled now. Option C is rejected because ImageMagick is the weaker choice for untrusted uploads.

## Consequences

- The warning goes away, and `ActiveStorage.variant_transformer` is the vips transformer in every environment that has libvips.
- The image keeps both toolkits: libvips for Active Storage variants, ImageMagick for the art build (ADR 0012). Neither replaces the other without a new ADR.
- Developers need libvips: `vips` on Fedora, `libvips` on Debian or Ubuntu. Without it Rails still boots, but logs "Generating image variants with libvips requires the ruby-vips gem", and the variant spec fails. It names the gem although the gem is bundled, because `image_processing` rewrites the load error.
- The first feature that accepts uploads still owes upload validation: content type and size ([security rule](../../.claude/rules/security.md)) and pixel limits. Active Storage 8.1 and `image_processing` 2.2 already call `Vips.block_untrusted(true)`, which blocks the unfuzzed loaders (e.g. the ImageMagick-backed `magickload`). That feature decides whether any of them should be re-enabled.
- Active Storage raises at boot if libvips is older than 8.13 (no `block_untrusted`). The image has 8.16.1, the development machine 8.18.3, and Ubuntu 24.04 has 8.15.1.
- If the project later drops variants altogether, Option B becomes the way to shrink the image, through an ADR that supersedes this one.
