---
name: spec-019-followups
description: Spec 019 (uncropped card images) — draft PR #66, the WebKit phone check owed, issue #65, ImageFit to upstream, conflicts expected with the spec 018 PR
metadata:
  type: project
---

State on 2026-10-11. Delete this memory when PR #66 merges and the items below are settled.

- **PR:** [#66](https://github.com/plainprogrammer/Collector/pull/66), a draft, closes #35. Branch `019-uncropped-card-images`, pushed at `9459479`; the session-wrap commits after it were not pushed at the time of writing.
- **Owed from the maintainer:** the spec's Reliability check on their phone's WebKit browser (grid, table and a card page from a dev server on the branch). It is recorded as owed in `docs/specs/019-uncropped-card-images/verification.md`, not claimed. See [[phone-lan-dev-access]].
- **Out of scope, tracked:** the 45% fade on tiles for cards you don't own is issue #65 (Scryfall's "do not desaturate or color-shift" line).
- **Upstreaming:** `ImageFit` is an override of the export in `collector/additions.css`. When a re-export of the published design system fits images with `contain`, delete the `Image fit (spec 019)` block in that PR; `spec/system/card_image_fit_spec.rb` then guards the export itself.
- **Merging beside spec 018 (issue #34):** both edit `collector/additions.css`, `docs/design-system/README.md` and `spec/design_system_files_spec.rb`. Spec 019's CSS block is mid-file and its examples are in a `describe` of their own. The second PR to merge keeps both sides, README lines in spec order. See [[pr-exists-and-conflicts-check]].
