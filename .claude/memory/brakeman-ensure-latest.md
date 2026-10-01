---
name: brakeman-ensure-latest
description: bin/brakeman uses --ensure-latest, so a new Brakeman release fails every commit and CI until the gem is bumped
metadata:
  type: reference
---

`bin/brakeman` runs with `--ensure-latest`. When Brakeman ships a release, the pre-commit hook and `bin/ci` start failing on every branch, with output like "Brakeman 8.0.6 is not the latest version 8.1.0" and exit 5, even though there are no warnings.

**How to apply:** run `bundle update brakeman --conservative`, check that `bin/brakeman` reports "No warnings found", and commit `Gemfile.lock` alone as `chore(deps): bump brakeman to X`. Use `git commit --only Gemfile.lock` if other work is staged. Don't drop `--ensure-latest`; it's deliberate CI policy.

First hit on 2026-09-30 (8.0.6 → 8.1.0, spec 006).
