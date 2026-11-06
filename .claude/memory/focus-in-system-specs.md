---
name: focus-in-system-specs
description: How to test keyboard focus after a Turbo Stream redraw in system specs, and how the scanner panel puts it back (spec 047)
metadata:
  type: project
---

Spec 047 (#182) put focus back after the scanner sitting panel is replaced by a Turbo Stream: the server names the target in `data-sitting-focus-to-value` on the redrawn panel, and `sitting_focus_controller.js` focuses it once and removes the attribute. A page render and an add name nothing.

**Why:** the replaced panel held the control the collector used, so focus fell to `<body>`; it is a pattern the next panel that redraws itself (number entry's list, bulk Undo) can reuse.

**How to apply when testing it:**
- `expect(page).to have_css("#scanner_sitting input[type=submit][value=Set]:focus")` is a waiting matcher: no sleeping. `find_button("Undo", match: :first).send_keys(:enter)` is the keyboard click.
- Headless Firefox matches `:focus-visible` for a script `focus()` after a keyboard Enter: the computed outline was `auto`/1px before the rule and `solid`/2px after. A click would not show the ring.
- An example that waits on state the old DOM already satisfies (the same status sentence, a "Set" the click already focused) passes without the feature: mark the old panel (`dataset.stale`), act, wait for `have_no_css("[data-stale]")`. See [[parallel-sdd-orchestration]] for how the plan review caught it.
- `RSpec/ExampleLength` is 15 and not autocorrectable: put the Tab-to-Set keyboard path in a helper.
- Turbo restores focus to an element with an id after a stream replace, one frame after `connect()`: a select that held focus while the answer was in flight can win over the move to "Set" (a known edge, spec 047 verification).
