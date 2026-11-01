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
