---
name: push-in-background
description: Run git push with run_in_background — the pre-push hook runs the full bin/ci (~20 min), and a foreground push blocks the session
metadata:
  type: feedback
---

Push with the Bash tool's `run_in_background: true` (a timeout of up to 2 hours), not in the foreground.

**Why:** the `.claude/settings.json` pre-push hook runs the full `bin/ci`, which took about 20 minutes at 2,182 examples (spec 032, 2026-10-25), even for a documentation-only push. On 2026-10-27 a foreground push held the session until the maintainer interrupted it, and they asked for pushes to run in the background so the main session stays available.

**How to apply:** start the push as its own background call, carry on with other work, and report when its notification arrives. Read its output file once for the `->` ref line. Speeding CI up is the spike in #145.

**Update (2026-10-31, #145):** the 20 minutes were one example (`name_parity_spec.rb:69`, about 1,490 s); with it fixed `bin/ci` takes about 6 minutes. The hook printed nothing because it timed out at 900 s and Claude Code let the push through. Both git hooks now set `"onFailure": "block"`, so a timed-out hook blocks the push: a push either ran `bin/ci` to a pass or was blocked. Backgrounding is still the rule, since 6 minutes still holds the session.

**Correction (2026-10-31, later):** the silent hook in that session wasn't only the timeout. After a worker restart, the session's project directory was `/home/user`, so no repository hook was loaded at all; see [[hooks-need-repo-project-dir]]. A push that returns in seconds means the hook didn't run, not that `bin/ci` passed.
