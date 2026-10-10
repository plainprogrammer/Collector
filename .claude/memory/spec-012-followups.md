---
name: spec-012-followups
description: Open follow-ups from spec 012 (GHCR image publishing) to feed a future spec — digest cleanup, smoke check, releasing.md lines, evidence still owed
metadata:
  type: project
---

Follow-ups from spec 012 (GHCR publishing, merged and released as `v0.1.0` on 2026-10-08), kept for a future spec:

- **Untagged digest cleanup** ([#17](https://github.com/plainprogrammer/Collector/issues/17)): built as spec 013 (`bin/ghcr-cleanup` + `.github/workflows/ghcr-cleanup.yml`), draft PR [#26](https://github.com/plainprogrammer/Collector/pull/26) opened 2026-10-08. Owed after merge (checklist in `docs/specs/013-ghcr-untagged-cleanup/verification.md`): a manual dry-run workflow run; after 2026-10-15T14:42:46Z (or the Sunday 2026-10-18 06:00 UTC run) the first real delete of the `f03eb827…` orphan unit, which answers whether `GITHUB_TOKEN` may delete (fallback: classic PAT); anonymous pulls of `latest`/`0.1.0`/`edge` on both architectures. Close #17 once that evidence is recorded.
- **Tighten the smoke check** ([#19](https://github.com/plainprogrammer/Collector/issues/19)). `bin/image-smoke` greps `catalog:status` output for `mtg`; it should match the exact `No mtg refresh runs yet.` that spec 012 AC-6.3 names.
- **`docs/releasing.md` additions** ([#20](https://github.com/plainprogrammer/Collector/issues/20)): "do not merge to `main` until go-public step 5 is done" (a merge mid-checklist moved `edge` during the first go-public), and use the anonymous `/users/plainprogrammer/packages/container/collector` API path so checks don't need `gh auth`.
- **Evidence still owed** ([#21](https://github.com/plainprogrammer/Collector/issues/21)) in `docs/specs/012-ghcr-registry-publishing/verification.md`: AC-3.2 at the first `1.0.0` release (the major-only tag), AC-3.3 at the first pre-release, and a live `bin/kamal deploy --skip-push --version X.Y.Z`.

**Why:** the maintainer asked (2026-10-08) to keep these for a future spec; the final Mode B review listed them as observations, not gaps.

**How to apply:** each item is tracked as a GitHub issue (#17, #19–#21; #18, ruby-vips, was done by spec 014 in PR #30); the issues are the source of truth for status. When planning the next release, deploy or image work, offer the open ones as brainstorm input, and remove items here as their issues close. Related: [[ghcr-and-actions-facts]].
