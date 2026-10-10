---
name: dev-machine-image-tools
description: Image tooling on the dev machine — ImageMagick 7 (magick), Pillow 12, ffmpeg and libvips 8.18.3 present (no vips command); ruby-vips 2.3.0 in the bundle, no mini_magick; Node 24 exists but no Node toolchain by rule
metadata:
  type: reference
---

Checked 2026-10-02 while planning spec 008:

- **Present:** ImageMagick 7.1.2 (`magick`, `convert`), Python 3 with Pillow 12.3 (no numpy, no cv2), ffmpeg, Firefox 156, Selenium Manager's geckodriver and Chrome for Testing under `~/.cache/selenium/`, Node v24 (`nodejs24-bin`) with npm.
- **libvips (corrected 2026-10-09, spec 014):** libvips 8.18.3 is installed (`vips-8.18.3-2.fc44`). `vips-tools` isn't, so there is no `vips` command; test for libvips with `bundle exec ruby -e 'require "ruby-vips"'`. The bundle has `ruby-vips` 2.3.0 (`require: false`) and `ffi` 1.17.4 with `image_processing` 2.2.0; `mini_magick` is not in it. The Dockerfile installs `libvips` at build and runtime.
- The house rule stays: no Node toolchain for the app; `bin/importmap pin --download` and `curl` from the npm registry are how JS is fetched.

**How to apply:** for image decoding in spikes or scripts on this machine, shell out to `magick <file> -depth 8 ppm:-` and parse the P6 header in Ruby, or use Pillow. `ruby-vips` works here too (Active Storage variants use it, ADR 0013); the art decoder stays ImageMagick (ADR 0012). Related: [[card-scanner-direction]].
