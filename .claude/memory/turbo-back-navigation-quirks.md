---
name: turbo-back-navigation-quirks
description: Turbo 8.0.23 frame "advance" + Back is racy (snapshot race, late page visit); filter pages now use plain Drive GET visits with no-cache; wait_for_turbo_idle
metadata:
  type: reference
---

How Turbo 8.0.23 (turbo-rails 2.0.23) behaved with a filter form targeting `turbo-frame#results` with `data-turbo-action="advance"`. The collection and search pages used that until 2026-10-02. Branch `004-filter-without-frames` replaced it with plain Turbo Drive GET visits, deviating from the design system's "results sit in a Turbo Frame" rule (maintainer ruling).

- **Snapshot race (root-caused 2026-10-01).** A frame advance pushes the URL, but its page visit is `willRender: false`, so `Turbo.session.view.lastRenderedLocation` stays at the old URL. Back's cache write could file the filtered page under the unfiltered URL. `turbo-cache-control: no-cache` closed this.
- **Late page visit (root-caused 2026-10-02).** `#loadFrameResponse` pushes the URL and swaps the frame, then `FrameRenderer#render` waits two repaints before `session.visit` marks `html[aria-busy]`. Nothing is busy in that gap, so `wait_for_turbo_idle` passed. Back in the gap was cancelled by the late visit's `navigator.stop()`, leaving "3 of 5 items" at `/collection`. `no-cache` doesn't help. It's reproduced by slowing `requestAnimationFrame` and delaying unfiltered fetches (`spec/system/back_navigation_spec.rb`).
- **Snapshots keep live form values, and cloned busy state goes stale.** Both only matter when a page is restored from a snapshot. The filter pages are `no-cache`, so Back/Forward refetch them, and the `url-sync` controller was removed.
- **Tests.** Call `wait_for_turbo_idle` (`spec/support/turbo_idle.rb`) before `go_back`/`go_forward`.

**How to apply:** don't reintroduce frame-advance filters; a GET form doing a Drive visit keeps state in the URL with a working Back. If a frame advance is ever needed, test Back with the slow-repaint helper. To see which path ran, instrument `turbo:visit`, `turbo:before-fetch-request`, `turbo:frame-load` and `turbo:load`, and log `html[aria-busy]`/`turbo-frame[busy]` every few ms. Related: [[headless-firefox-narrow-frame]], [[pr5-open-followups]].
