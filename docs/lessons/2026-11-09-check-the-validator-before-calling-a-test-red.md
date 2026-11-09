---
date: 2026-11-09
spec: none
tags: [testing, bug-fix, rails]
---

# Lesson: check what the framework's validator already does before calling a test red

## Context

#230 said a sign-up with a "missing or blank" password confirmation created the account, and asked for a failing test first.

## What happened

`has_secure_password` declares its confirmation check with `allow_nil: true`, so the validator skips only a `nil` confirmation. A blank one (`""`) never differed from a mismatch and was already refused. Only an omitted field was the gap. The blank example passed before the fix; it is a regression pin, not a red test. The fix was one line in `Registration` (an omitted confirmation is checked as the empty one).

## What to do next time

- Run the issue's cases against the unfixed code and read the framework's validator before writing the plan. Issue text can overstate a gap.
- Say in the PR which example was red and which pins existing behaviour.
