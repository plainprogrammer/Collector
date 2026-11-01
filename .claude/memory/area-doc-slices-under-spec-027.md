---
name: area-doc-slices-under-spec-027
description: Spec 027 slice C area docs run directly under spec 027 — no PRD, new spec number or ADR; a brainstorm only settles scope in chat
metadata:
  type: feedback
---

An area-doc slice of spec 027 (slice C: one area per pull request) runs directly under spec 027. It gets no `prd.md`, no new spec number and no ADR, as #129 (data portability) and #130 (release and deploy) did.

**Why:** the maintainer chose this on 2026-10-27 for #105 (collection and lots), when asked how to frame the slice. Spec 027 D9 says area docs make no decisions of their own, so an ADR or a new spec would be ceremony.

**How to apply:** if `sdd-brainstorm` is invoked for such a slice, use it only to settle scope questions in chat: which specs and parts the doc covers, what freezes whole or in part, which plans retire, and the doc's edges. Then:
1. write the area doc and its row in `docs/architecture/README.md`;
2. run a read-only review of the doc;
3. make the frozen lines, plan retirements and pointers, one commit each (spec 027 D4);
4. move the CLAUDE.md bullets to a pointer and update the specs index.

Take the scope from the index's Areas column, not only from the issue (lesson `2026-10-27-area-doc-scope-from-the-index`).
