---
name: spec-012-followups
description: Open follow-ups from spec 012 (GHCR image publishing) to feed a future spec — digest cleanup, ruby-vips, smoke check, releasing.md lines, evidence still owed
metadata:
  type: project
---

Follow-ups from spec 012 (GHCR publishing, merged and released as `v0.1.0` on 2026-10-08), kept for a future spec:

- **Untagged digest cleanup** ([#17](https://github.com/plainprogrammer/Collector/issues/17)). Every publish leaves two untagged per-architecture versions, and every re-run orphans a whole manifest list. Nine of twelve package versions were untagged on 2026-10-08. Candidate fix: a scheduled workflow deleting untagged versions older than N days.
- **ruby-vips vs libvips** ([#18](https://github.com/plainprogrammer/Collector/issues/18)). The `Dockerfile` installs `libvips` but the `Gemfile` has no `ruby-vips`, so Rails tasks in the image warn "Generating image variants with libvips requires the ruby-vips gem". Either add the gem (Active Storage variants) or drop `libvips` to shrink the image.
- **Tighten the smoke check** ([#19](https://github.com/plainprogrammer/Collector/issues/19)). `bin/image-smoke` greps `catalog:status` output for `mtg`; it should match the exact `No mtg refresh runs yet.` that spec 012 AC-6.3 names.
- **`docs/releasing.md` additions** ([#20](https://github.com/plainprogrammer/Collector/issues/20)): "do not merge to `main` until go-public step 5 is done" (a merge mid-checklist moved `edge` during the first go-public), and use the anonymous `/users/plainprogrammer/packages/container/collector` API path so checks don't need `gh auth`.
- **Evidence still owed** ([#21](https://github.com/plainprogrammer/Collector/issues/21)) in `docs/specs/012-ghcr-registry-publishing/verification.md`: AC-3.2 at the first `1.0.0` release (the major-only tag), AC-3.3 at the first pre-release, and a live `bin/kamal deploy --skip-push --version X.Y.Z`.

**Why:** the maintainer asked (2026-10-08) to keep these for a future spec; the final Mode B review listed them as observations, not gaps.

**How to apply:** each item is tracked as a GitHub issue (#17–#21); the issues are the source of truth for status. When planning the next release, deploy or image work, offer the open ones as brainstorm input, and remove items here as their issues close. Related: [[ghcr-and-actions-facts]].
