---
name: verify-red-run-claims
description: An implementer's "passed before the change" (or "failed red") report can be wrong; check by removing the new code and running that example
metadata:
  type: reference
---

An implementer subagent's report of its red run can be wrong. In spec 042 Task 3 (2026-11-06) the implementer said the AC-4.5 examples "passed at that point", before the condition check existed, which would have made the refusal example a guard that can't fail. The check that settled it: delete the new line (`sed -i '' '/raise Refused, :condition/d' app/models/scanner/sitting.rb`), run only that example (`bin/rspec spec/models/scanner/sitting_spec.rb:184`), then `git checkout -- <file>`. It failed, on `Lot`'s `RecordInvalid`, so the example was sound and the report was not.

**How to apply:** when a report says a new example passed before its change, or names an odd failure, and the plan didn't predict that, reproduce it this way before accepting the task. A committed file makes the removal safe to undo. Related: the lesson `docs/lessons/2026-11-06-reset-guards-pass-before-their-code.md` (a guard that passes before its code exists; prove it red by removing the line), [[sdd-execute-exact-plans]].
