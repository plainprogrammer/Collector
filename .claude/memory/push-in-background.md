---
name: push-in-background
description: Run git push with run_in_background — the pre-push hook runs the full bin/ci (~20 min), and a foreground push blocks the session
metadata:
  type: feedback
---

Push with the Bash tool's `run_in_background: true` (a timeout of up to 2 hours), not in the foreground.

**Why:** the `.claude/settings.json` pre-push hook runs the full `bin/ci`, which took about 20 minutes at 2,182 examples (spec 032, 2026-10-25), even for a documentation-only push. On 2026-10-27 a foreground push held the session until the maintainer interrupted it, and they asked for pushes to run in the background so the main session stays available.

**How to apply:** start the push as its own background call, carry on with other work, and report when its notification arrives. Read its output file once for the `->` ref line. The hook may print nothing about `bin/ci`; say that it let the push through, not that `bin/ci` passed. Speeding CI up is the spike in #145.
