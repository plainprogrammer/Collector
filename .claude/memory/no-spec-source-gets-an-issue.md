---
name: no-spec-source-gets-an-issue
description: When distilling into an area doc finds code behaviour that no spec, ADR or issue states, open an issue for the maintainer to rule on, even if nothing contradicts it (maintainer, 2026-10-15, spec 027 → #111)
metadata:
  type: feedback
---

When distilling a feature into an area doc (`distill-feature`, or a slice C back-fill) turns up behaviour in the code that no spec, ADR or issue states, open a GitHub issue for the maintainer to rule on, even if no source contradicts it. The issue says what the code does (with file:line and the test that pins it), why no spec covers it, and what would need deciding. The area doc states the behaviour, marked "no spec source", and links the issue from the statement, from "Accepted limits and open issues" and from Sources. The doc doesn't wait for the ruling.

**Why:** spec 027's Error Scenarios call for an issue only when the code contradicts every source. Its controller read that narrowly and didn't open one for the `poll` controller's pauses (hidden tab, busy Turbo, open menu), which came from spec 015's plan rather than its spec. The maintainer overruled that the same day, and the issue became #111. Once a plan is retired, behaviour like this is recorded only in the code and a test that cites a criterion that doesn't state it.

**How to apply:** issues are public, so in a supervised run, send the draft to the coordinator before creating it. Once the issue exists, it is an open issue bearing on the area, so it joins the AC-1.7-style list of known limits. Related: [[edit-specs-your-change-makes-stale]].
