---
name: edit-specs-your-change-makes-stale
description: When a change makes part of a shipped spec stale, record the supersession in the new spec and the specs index and update the area doc; never edit the earlier spec (rulings R3 and R8 of 2026-10-15, spec 027). Replaces the 2026-10-14 practice of editing it with a version bump
metadata:
  type: feedback
---

When a change makes an acceptance criterion or requirement of a shipped spec incomplete or wrong, don't edit that spec. Record the supersession in the new spec ("supersedes spec NNN AC-x: …"), add it to `docs/specs/README.md` in both directions, and update the area doc under `docs/architecture/` where one covers that part.

**Why:** on 2026-10-15 the maintainer ruled that specs freeze as historical records once an area doc covers them (spec 027, R3), and that freezing applies already (R8): spec 025's plan was told not to edit spec 022 and to record the supersession in spec 025, and spec 026 got the same instruction. Specs 002 and 015 had been amended in place for issues #60–#81, which hid what each promised when it shipped.

**History:** from 2026-10-14 (spec 024) to 2026-10-15 the practice was the opposite. Spec 024's plan said spec 015's AC-2.16 would become incomplete and that the PR would only note it; approving the plan on 2026-10-14, the maintainer said: "Also edit spec 015's AC-2.16 wording in this PR so it covers the new 'waiting for another job's retry' skip (bump its version per house style)." Spec 015 went to v1.3.1 with a changelog line, in the same docs commit as spec 002's update. Those edits stay as they are.

**How to apply:** while specifying or planning, grep `docs/specs/` and `docs/architecture/` for the behaviour, scope or message you change. For each part of a shipped spec it makes stale, write the supersession into your spec, plan the index rows and the area doc edit, and record them in your `verification.md`. Only a spec's frozen line, retirement pointer and links to its retired plan may be added to it (spec 027 D4). Related: [[sdd-review-model-choice]].
