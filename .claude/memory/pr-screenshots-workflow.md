---
name: pr-screenshots-workflow
description: How to capture UX screenshots/GIF for a PR and embed them in this private repo's PR body
metadata:
  type: reference
---

- **Capture:** headless Firefox via `selenium-webdriver` works; Selenium Manager fetches geckodriver automatically. Drive a dev server that has real catalog data. Take full-page PNGs with `save_full_page_screenshot`, after scrolling so the lazy images load.
- **Phone widths:** headless Firefox won't go below 500px, so capture 390px shots from a fixed-width same-origin iframe (see [[headless-firefox-narrow-frame]]). Spec 004's `docs/specs/004-design-system-collection/screenshots/` is the worked example.
- **Look at every shot:** the 004 walkthrough found four UI bugs that specs and reviews missed.
- **Compress:** `magick in.png -resize 1000x -crop 1000x2400+0+0 +repage -quality 82 out.jpg` gives about 150–300 KB each.
- **Walkthrough:** save viewport frames, repeating a frame to hold it longer. Then run `ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 walkthrough.gif`, which gives about 600 KB for 45 frames.
- **Store:** commit to `docs/specs/NNN-slug/screenshots/` on the feature branch. The user chose committing over manual upload.
- **Embed:** the repo `plainprogrammer/Collector` is **private**. Use `https://github.com/plainprogrammer/Collector/blob/<commit-sha>/<path>?raw=true`, pinned to a SHA so the links survive merge and branch deletion. `gh` cannot upload images.

**How to apply:** when a PR needs UX evidence, follow this pipeline; spec 002's PR #3 is the worked example. Run the server as in [[background-servers-via-task]].

**Theme switches (spec 015, 2026-10-10):** `c-btn` transitions its background over 0.12s. A shot taken right after setting `data-theme` by script shows pale buttons that look like a dark-mode bug. Pause about 0.6s after each switch, in the page and inside the narrow frame. Set `$stdout.sync = true` in capture scripts, or a background run shows no output until it ends.
