---
name: turbo-back-navigation-quirks
description: Turbo 8.0.23 Back after a frame "advance" search - two restore paths, snapshots keep form values, stale busy state; url-sync and wait_for_turbo_idle
metadata:
  type: reference
---

This is how Turbo 8.0.23 (turbo-rails 2.0.23) behaves after a frame `data-turbo-action="advance"` navigation. The search and collection filter forms sit outside `turbo-frame#results`.

- **Two restore paths on Back.** If a snapshot of the previous page was cached (normally within about 10 ms), Turbo renders it with no fetch. Otherwise it re-fetches the page. Which one happens depends on timing.
- **Snapshots keep live form values.** `PageSnapshot.clone()` copies typed input and select values, so Back restored the old results but left "bolt" in the search box. The `url-sync` Stimulus controller (`app/javascript/controllers/url_sync_controller.js`) resets the filter fields from the URL on `turbo:load`.
- **Stale busy state.** The snapshot is cloned while the frame and form still carry `busy`/`aria-busy`, so a restored page can keep them until the next navigation. This is an accessibility problem that isn't fixed; see [[pr5-open-followups]].
- **Snapshot race, root-caused 2026-10-01.** A frame `data-turbo-action="advance"` pushes the URL, but its follow-up visit is `willRender: false`, so `Turbo.session.view.lastRenderedLocation` stays at the old URL (`/collection`). On Back, the restoration visit's `turbo:before-cache` caches the current, filtered page under that old key. Normally Back has already read the cached snapshot, but on a slow runner the write lands first and Back restores the filtered results ("3 of 5 items") at the unfiltered URL. Reproduce it deterministically by calling `Turbo.session.view.cacheSnapshot()` after filtering, then `go_back` (`spec/system/back_navigation_spec.rb`). Fix: `<meta name="turbo-cache-control" content="no-cache">` (via `content_for :head`) on the collection and search pages, so Back refetches them. Still a Turbo visit, so `window` state survives.
- **Tests.** Wait for Turbo to be idle before `go_back`/`go_forward` (`spec/support/turbo_idle.rb`, `wait_for_turbo_idle`). The frame-busy check has to be skipped (`frames: false`) before `go_forward`, because of the stale busy state.

**How to apply:** when adding a frame-targeted filter form, attach `url-sync`, and use `wait_for_turbo_idle` in back/forward system specs. To see which restore path ran, instrument the `turbo:visit`, `turbo:before-fetch-request` and `turbo:render` events. Related: [[headless-firefox-narrow-frame]].
