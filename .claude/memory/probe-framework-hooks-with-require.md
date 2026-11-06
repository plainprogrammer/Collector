---
name: probe-framework-hooks-with-require
description: Find which pages a framework hook (e.g. field_error_proc) affects by wrapping it in a scratch RSpec config loaded with bin/rspec --require; call the original with instance_exec
metadata:
  type: reference
---

To find which pages a framework hook affects, write a scratch RSpec config file in the session scratchpad. In `before(:suite)` it swaps the hook for a logging wrapper keyed by `RSpec.current_example&.location`, and `after(:suite)` prints the log. Run it against the existing specs with `bin/rspec --require <absolute path> <files>`; nothing tracked is edited.

Rails calls `field_error_proc` with `instance_exec` on the view, so pass the original through the same way: `instance_exec(html, tag, &original)`. A plain `original.call(html, tag)` raises "undefined method 'content_tag' for class ActionView::Base" (spec 044, 2026-11-06: 17 examples broke on the first attempt, though the log was still right).

**Why:** spec 044's probe showed in one run that the wrapper appeared on eight forms and not on sign-in, number entry or Currency, so the spec's problem statement named real facts, not the issue's guesses.

**How to apply:** before writing a spec's problem statement, when the issue lists the places it suspects a framework behaviour, probe them with the existing specs this way. Related: [[pr-screenshots-workflow]].
