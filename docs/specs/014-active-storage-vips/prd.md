# PRD: Active Storage variants with vips

**Date:** 2026-10-09
**Feature:** 014-active-storage-vips
**Issue:** [#18](https://github.com/plainprogrammer/Collector/issues/18)

## Problem

Every Rails command run in the published container image logs "Generating image variants with libvips requires the ruby-vips gem". This includes `catalog:status`, `collector:user`, server boot and the smoke test. The image installs `libvips` (Rails' default `Dockerfile`), and `load_defaults 8.1` makes vips the Active Storage variant processor, but the bundle has no `ruby-vips`.

The warning is harmless today, because nothing uses variants yet. Still, it is noise in self-hosters' logs that looks like a fault, it has to be filtered out of the image's output in checks (spec 011 `research.md` §2), and it means variants would not work if a feature used them.

## Users & Context

- **Self-hosters** run the published image (Compose or Kamal) and read its logs. A warning on every command suggests a broken install.
- **Maintainers and agents** run Rails tasks in the image to verify releases (spec 012) and art builds (spec 011).
- **Future features:** the maintainer expects user-uploaded images, with thumbnails, for comics and other collectible types, and perhaps for slabbed or graded cards. Those features need working Active Storage variants.

It touches the `Gemfile`, `bin/setup`'s dependency checks, the CI workflow (`.github/workflows/ci.yml`), `bin/image-smoke`, and the README's requirements. The `Dockerfile` already installs libvips, and its packages don't change. Art decoding keeps ImageMagick ([ADR 0012](../../adr/0012-decode-art-images-with-imagemagick.md)).

## Goals

- Rails commands in the production image log no vips warning: neither "requires the ruby-vips gem" nor "requires the libvips library".
- Active Storage variants work with libvips in production, development and CI.
- Development mirrors production: `bin/setup` reports a missing libvips with install instructions, as it does for ImageMagick, and CI installs it. "libvips present" means `ruby-vips` loads (e.g. `bundle exec ruby -e 'require "ruby-vips"'`), not that the `vips` command exists: Fedora's `vips` package provides the library, but the command is in `vips-tools`.
- The app still boots where libvips is missing: `Bundler.require` must not load `ruby-vips`. Active Storage loads it itself after initialization and rescues the failure.
- The image check (`bin/image-smoke`) catches a regression.

## Non-Goals

- Any upload feature: attachments, upload validation, thumbnails in a view.
- Removing ImageMagick or changing the art decoder (ADR 0012).
- Removing Active Storage, Action Text or Action Mailbox.
- Shrinking the image.

## Success Criteria

- `bin/rails runner` in the built image prints neither vips warning, and reports `ActiveStorage.variant_transformer` as `ActiveStorage::Transformers::Vips`. `bin/image-smoke` asserts both, on amd64 and arm64.
- A spec turns a small fixture image into a resized variant by calling `ActiveStorage.variant_transformer` directly (e.g. `resize_to_limit`), with no blobs or `active_storage_*` tables, and checks the output's dimensions. It passes locally and in CI. `spec/fixtures` has no image yet, so the spec adds a small one.
- `bin/setup` on a machine without libvips prints an install hint and carries on. On a machine with it, it prints nothing extra.
- `bin/ci` passes, and the README's requirements list libvips (and ImageMagick, which it doesn't mention yet).

## Architecture Decisions

- [0013: Process Active Storage variants with libvips through `ruby-vips`](../../adr/0013-active-storage-variants-with-vips.md). Commit to Rails' default processor now: it suits untrusted, large uploads, and libvips is already in the image. The gem is `require: false`, so boot doesn't depend on libvips.

Not ADR-worthy, noted here: the `ruby-vips` version constraint (`~> 2.3`, as Rails' warning suggests) and installing libvips in CI next to `imagemagick`. On `ubuntu-latest` (24.04) the runtime package is `libvips42t64`. The plan confirms the exact name, or uses the `libvips` metapackage the `Dockerfile` installs.

## Out of Scope

- **Disabling variants and dropping libvips** to shrink the image by about 90 MB. Considered and rejected (ADR 0013, Option B).
- **ImageMagick for variants (`mini_magick`).** Rejected (ADR 0013, Option C).
- **Upload validation, and whether to re-enable any libvips loaders `Vips.block_untrusted` blocks.** These are owed by the first feature that accepts uploads (ADR 0013, Consequences).
- **Tightening the smoke check's `catalog:status` grep** ([#19](https://github.com/plainprogrammer/Collector/issues/19)).
