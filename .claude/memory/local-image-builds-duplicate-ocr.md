---
name: local-image-builds-duplicate-ocr
description: Until issue #31 is fixed, images built in a set-up checkout carry the OCR engine twice (~14 MB), so don't compare local image sizes with published ones
metadata:
  type: project
---

An image built with `podman build` in a checkout that `bin/setup` has prepared holds the OCR engine twice: `/rails/vendor/ocr/v7.0.0` and a stray `/rails/vendor/v7.0.0` (14,496 KB each). `Dockerfile:39` (`COPY vendor/* ./vendor/`) copies the contents of each matched directory, and `vendor/ocr/` is git-ignored but not in `.dockerignore`. CI builds from a fresh checkout, where `vendor/ocr/` doesn't exist; the published `0.1.0` has no duplicate (`edge` wasn't checked). Tracked in [#31](https://github.com/plainprogrammer/Collector/issues/31), opened 2026-10-09.

**Why:** it skewed spec 014's size comparison: the local image was 20.7 MB larger than `0.1.0`, while the feature's real growth was 2.7 MB.

**How to apply:** until #31 closes, don't compare a local image's total size with a published image's. Measure the paths that changed with `du -sk` inside the image (e.g. `/usr/local/bundle`, a gem's `bundle info --path`). Delete this memory when #31 is closed. Related: [[ghcr-and-actions-facts]], [[dev-machine-image-tools]].
