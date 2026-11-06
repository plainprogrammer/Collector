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

**Set the light theme explicitly too (spec 037, 2026-11-06):** headless Firefox reports `prefers-color-scheme: dark`, so a page with no `data-theme` renders dark, and Turbo Drive keeps `<html>`'s attributes across visits, so a theme set by script survives the next Turbo navigation but not a full load. Spec 037's first "light" shots came out dark until each shot set `data-theme` from its name (`-light`/`-dark`) right before saving. Look at the first shot of each theme before trusting the rest.

**Worktree dev data (spec 023, 2026-10-14):** a fresh worktree's dev database had 0 catalog entries and 0 users. Rather than run a full refresh, a scratch script in the session scratchpad (`bin/rails runner`) seeded one user, one applied `Catalog::RefreshRun` (so the app is past first run and shows results) and six printings of one name across three sets. Tiles then show placeholders, not card art. Say so in the PR body, and mention the seed left in the worktree's dev DB in the final report. To show an opt-in setting, start the dev server with it (`COLLECTOR_PUBLIC_CATALOG=true bin/dev`). Quality 55 and 1000px-wide 1280 shots gave 30–40 KB each, 280 KB for eight.

**Refused (422) states (spec 044, 2026-11-06):** reach each by the real form with `form.noValidate = true` then `form.requestSubmit()`. Native `min`/`max`/`required`/`type=email` stop a real click, and `form.submit()` skips Turbo, so the page fully reloads and loses the `data-theme` the script set. A value the script injected (an extra select option, text typed into a number field) is gone from the re-rendered page, so the shot shows the default; say so in `verification.md`. Seed with one script written by the Write tool and run `bin/rails runner <path>` alone in its own Bash call, every need batched into it: a chained command (heredoc, `db:prepare`, `git status`, runner) stopped at a permission prompt that only the maintainer could answer.

**Screenshots from a throwaway system spec (specs 042 and 041, 2026-11-06):** instead of a dev server and a seed script (`bin/rails runner` prompts), write an uncommitted spec under `spec/system/` (e.g. `zz_<NNN>_screenshots_spec.rb`) that builds the data with factories (`owned_printing`, `create(:location, …)`), visits the pages and saves each shot into the session scratchpad: `page.save_screenshot(File.join(ENV.fetch("SHOTS_DIR"), …))` for a page, `find(sel).native.save_screenshot(path)` for an element, `find("#narrow").native.save_screenshot` for a 390px frame opened with `open_in_narrow_frame`. Run it with `SHOTS_DIR=<scratchpad> bin/rspec <file>`, then delete it before committing. Set `data-theme` in the page and inside the frame, pausing about 0.6–0.7s. On the scanner, measure positions inside the frame only after a settle wait: the camera stage grows after load, so a frame sized or cropped from an early measurement misses the panel. Crop and compress with `magick` as above. No permission prompt, no seed left in the dev DB, the same data each run (spec 041: 11 shots in 13 s); say "factory data, placeholder printings" in the PR body.
