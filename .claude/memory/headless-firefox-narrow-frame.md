---
name: headless-firefox-narrow-frame
description: Headless Firefox won't render windows under 500px; test and screenshot phone widths in a fixed-width same-origin iframe
metadata:
  type: reference
---

Headless Firefox (Selenium, system specs and screenshot scripts) clamps the window to at least 500px wide. A `driven_by … screen_size: [390, 844]` driver actually renders at 500px, so phone-width assertions silently test the wrong layout.

- **Specs:** use `spec/support/narrow_frame.rb` (`open_in_narrow_frame(path, width:, height:, ready:)` returns `[innerWidth, no_horizontal_overflow]`, and `within_narrow_frame { … }`) with the normal driver. Media queries and container queries evaluate against the iframe's own width. Prove each narrow assertion by breaking the CSS once. Touch-target and coarse-pointer rules still can't be tested this way.
- **Screenshots:** inject a fixed-width iframe on a same-origin page, grow the frame to its content height, resize the window taller than the frame, then take an element screenshot of the frame. Without the taller window only the visible part is captured.
- Separately named drivers (`options: { name: :firefox_dark }`) are still needed for different Firefox prefs, e.g. the dark theme, because Capybara reuses sessions by driver name.

Related: [[pr-screenshots-workflow]].
