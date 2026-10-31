---
name: browser-spec-image-and-window-gotchas
description: System specs that load card images or resize the window — the 127.0.0.1:9 plus data: picture helper, decode() vs load, around hooks, saved collection view, float noise
metadata:
  type: reference
---

Found by running, while planning spec 019 (2026-10-11, headless Firefox 157). The measured values are in `docs/specs/019-uncropped-card-images/plan.md` under "Facts established during planning".

- **Card images in the browser:** a card image tag renders only for an `https` address on a source's allowed host (`catalog_url`), and WebMock doesn't stop Firefox's requests. Tag the example `:card_images` and use `spec/support/card_images.rb`: `card_image_address` gives `https://127.0.0.1:9/…` (Firefox refuses the port, nothing leaves the machine), `card_picture(w, h)` a `data:` picture, `card_image_fits` where the browser paints it, `card_slot_boxes` the boxes.
- **`image.decode()` doesn't wait for a newly set `src`** in Firefox: the second picture given to an image was measured with the first one's size. Wait for the `load` event.
- **An `around` hook runs before `driven_by`** (`Capybara::NotSupportedByDriverError` on `page.current_window`). Resize in `before`. The driver's window size is set once per session, so a resize outlives the example; since 2026-10-31 `spec/support/system.rb` puts the window back to `SYSTEM_SCREEN_SIZE` after every system example, so specs don't restore it themselves. (Before that, `admin_catalog_spec`'s 1000×500 window hid the More page's links in `number_entry_spec`'s 800px narrow frame under seed 12061.)
- **The collection's view is a saved preference.** After one visit to the table, `collection_path` shows the table. Always pass `view:`.
- **`getBoundingClientRect` sizes carry float noise** (33.51666 against 33.51667). Round before comparing sizes for equality.
- **`owned_printing` returns a lot whose `entry.extension` isn't loaded.** Set faces on the `MTG::Printing` itself.
- **A sub-pixel change doesn't show in a screenshot.** Compare boxes and computed styles.
- **Downloads (spec 022):** `spec/support/system.rb` sets `browser.download.folderList` = 2 and `browser.download.dir` to `DOWNLOADS` (`tmp/downloads`, git-ignored). On headless Firefox 157 those two alone save an attachment without a dialog. `browser.helperApps.neverAsk.saveToDisk` is a legacy preference and isn't needed. Wait for the file with `page.document.synchronize(10) { raise Capybara::ExpectationNotMet … }` until it exists, isn't empty and has no `.part` beside it. Work out its name before the click.
- **The suite never sets `Capybara.default_max_wait_time`,** so a bare `synchronize` or matcher waits Capybara's default of 2 s. Pass a bound (`synchronize(10)`, `wait: 30`) when the browser does real work.

Related: [[headless-firefox-narrow-frame]], [[pr-screenshots-workflow]].
