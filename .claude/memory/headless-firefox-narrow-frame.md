---
name: headless-firefox-narrow-frame
description: Headless Firefox won't render windows under 500px; test and screenshot phone widths in a fixed-width same-origin iframe
metadata:
  type: reference
---

Headless Firefox (Selenium, system specs and screenshot scripts) clamps the window to at least 500px wide. A `driven_by … screen_size: [390, 844]` driver actually renders at 500px, so phone-width assertions silently test the wrong layout.

- **Specs:** use `spec/support/narrow_frame.rb` (`open_in_narrow_frame(path, width:, height:, ready:)` returns `[innerWidth, no_horizontal_overflow]`, and `within_narrow_frame { … }`) with the normal driver. Media queries and container queries evaluate against the iframe's own width. Prove each narrow assertion by breaking the CSS once. Touch-target and coarse-pointer rules still can't be tested this way. The window must be taller than the frame: links below the window's bottom edge can't be clicked, and the click silently does nothing (seed 12061, 2026-10-31).
- **Screenshots:** inject a fixed-width iframe on a same-origin page, grow the frame to its content height, resize the window taller than the frame, then take an element screenshot of the frame. Without the taller window only the visible part is captured.
- Separately named drivers (`options: { name: :firefox_dark }`) are still needed for different Firefox prefs, e.g. the dark theme, because Capybara reuses sessions by driver name.

Related: [[pr-screenshots-workflow]].

**Additions from spec 018 (2026-10-11):**
- The frame can't be opened from a scanner page: its Content-Security-Policy sets `frame-src 'none'`, so the frame stays empty and the `ready` selector is never found. Visit another page first (the collection), then open the scanner in the frame.
- To test anything about the end of a page under the fixed tab bar, use a frame much shorter than the page (320px tall) and assert `scrollY > 0` after scrolling to the end. In an 844px frame a short page never scrolls, and "the last line is above the tab bar" then proves nothing. A frame only just shorter than the page (480px for the More page) passes by a few pixels of font metrics.
- An element screenshot of the frame (`find("#narrow").native.save_screenshot`) is cut off at the window's edge. Resize the window taller than the frame first (`page.current_window.resize_to(1280, 1000)` for an 844px frame).
- Measure related boxes in one script call. Two calls raced on the scanner page, which grows while the camera starts.
- **Keyboard-only selects (spec 041, 2026-11-06):** under WebDriver in headless Firefox, arrow keys don't change a closed `<select>`'s value (its `selectedIndex` stays 0 whether or not the list opens). A keyboard-only example chooses by type-ahead instead: focus the select and `send_keys` the option's first letter.
- **Scrollbars are pinned to classic (#271, 2026-11-10):** on a Mac, Firefox follows "Show scroll bars: Automatic" and draws overlay scrollbars (no width) when no mouse is connected, which made a 360px frame 15px wider than CI's and broke a wrap check locally only. `spec/support/system.rb` now sets `ui.useOverlayScrollbars = 0`. A driver registered under another name (the dark-theme ones) needs the same pref if it opens a narrow frame. See `docs/lessons/2026-11-10-a-local-only-failure-was-the-macs-scrollbar-setting.md`.
- **A 360px frame is not a 360px phone (spec 069, 2026-11-11):** the frame keeps the forced classic scrollbar (15px on the Mac, about 12px on CI) and the body has an 8px margin, so a 360px frame's page container is 297px (360 − 15 − 16 body − 32 padding) and a deck-shape panel's interior 263px; a real 360px viewport gives a 312px container and a 278px interior. Model a phone as a **375px frame** (a 360px viewport). The `@container page` breakpoints (640px, 992px) are on the container (frame − 15 − 16 − page padding): a 640px frame is a 545px container and still shows the fold; the aside needs a frame of 735px or more. Write the chain in the spec; see `docs/lessons/2026-11-11-a-phone-width-criterion-needs-a-measured-chain.md` and #318 (the helper misses overflow a scrollbar hides). The pinned classic scrollbar is 15px on the Mac but about 12px on the Linux CI runner (spec 069's first CI run, interior 281px vs 278px): size a phone frame from the measured `innerWidth - documentElement.clientWidth`, `360 + scrollbar`, not 375.
