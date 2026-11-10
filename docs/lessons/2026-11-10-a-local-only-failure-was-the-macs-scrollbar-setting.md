---
date: 2026-11-10
spec: 048 (AC-1.8), issues #271, #288
tags: [testing, system-specs, firefox, ci]
---

# Lesson: a local-only system-spec failure was the Mac's scrollbar setting

## Context

On 2026-11-10 every local `bin/ci` began failing `spec/system/collection_row_place_spec.rb:93` (spec 048 AC-1.8: a five-character set code wraps the table row's place line at 360px). GitHub CI stayed green on the same commits. The pre-push hook runs `bin/ci`, so every worker's push was blocked. The failure reproduced alone, in the full suite, and in two different worktrees, and nothing in the code, fonts, test data or Firefox (Selenium Manager's 159.0.1, last updated 5 November) had changed.

## What happened

Headless Firefox follows macOS's "Show scroll bars" setting, which defaults to "Automatically based on mouse or trackpad". While a mouse was connected, Firefox drew classic scrollbars, which take 15px of the frame. Once only the trackpad was attached, it drew overlay scrollbars, which take none. The narrow frame's page always scrolls (816px of content in an 800px frame), so the setting changes its content width:

| `ui.useOverlayScrollbars` | width | frame clientWidth | `.c-table__sub` height |
|---|---|---|---|
| 0 (classic) | 360 | 345 | 32 (wraps) |
| 1 (overlay) | 360 | 360 | 16 (one line) |

The line wraps by only about 5px with a classic scrollbar, so those 15px decided the result. CI's Linux Firefox draws classic scrollbars, which is why CI passed.

The failure screenshot looked like it showed a classic scrollbar. It was the thin overlay thumb.

## The fix

`spec/support/system.rb` pins `ui.useOverlayScrollbars = 0` next to the colour-scheme pin from #118 (#272), so local runs match CI whatever pointing device is connected.

## What to do next time

- When a browser spec fails locally but passes on CI, and nothing in the repo changed, compare the browser's environment with CI's before reading code. Check the OS appearance settings (scrollbars, dark mode, font smoothing), the attached devices, and the browser's prefs. Pin any that a layout depends on in `spec/support/system.rb`.
- Measure inside the frame (`clientWidth`, element heights) under both settings; a probe spec in the scratchpad did it in minutes.
- An assertion that passes by a few pixels is fragile. AC-1.8's wrap only holds at a 345px content width, which a real phone (overlay scrollbars) doesn't have; #288 restates it.
