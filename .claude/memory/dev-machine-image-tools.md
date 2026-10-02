---
name: dev-machine-image-tools
description: Image tooling on the dev machine — ImageMagick 7 (magick), Pillow 12, ffmpeg present; no libvips, no ruby-vips/mini_magick in the bundle (Dockerfile has libvips); Node 24 exists but no Node toolchain by rule
metadata:
  type: reference
---

Checked 2026-10-02 while planning spec 008:

- **Present:** ImageMagick 7.1.2 (`magick`, `convert`), Python 3 with Pillow 12.3 (no numpy, no cv2), ffmpeg, Firefox 156, Selenium Manager's geckodriver and Chrome for Testing under `~/.cache/selenium/`, Node v24 (`nodejs24-bin`) with npm.
- **Absent:** libvips (no `libvips.so.42`), so `require "vips"` fails even though a `ruby-vips` user gem exists; `ruby-vips` and `mini_magick` are not in `Gemfile.lock` (`image_processing` 2.1.0 is, with no backend). The app's Dockerfile installs `libvips` at build and runtime, so the container has vips and the dev machine doesn't.
- The house rule stays: no Node toolchain for the app; `bin/importmap pin --download` and `curl` from the npm registry are how JS is fetched.

**How to apply:** for image decoding in spikes or scripts on this machine, shell out to `magick <file> -depth 8 ppm:-` and parse the P6 header in Ruby, or use Pillow. Don't plan on `ruby-vips` here without installing libvips (`dnf install vips`), and say in findings what the production image would need if the app ever processes images at refresh. Related: [[card-scanner-direction]].
