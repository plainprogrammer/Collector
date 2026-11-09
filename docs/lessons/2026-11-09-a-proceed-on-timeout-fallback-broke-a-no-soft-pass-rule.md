---
date: 2026-11-09
spec: 031
tags: [review, upgrade-proof, spec-rules]
---

# Lesson: check the area's "no soft pass" rule before proposing a fallback

## Context

#177's harness fix waits for Solid Queue's processes to log `Started` before it stops an instance. I proposed that a wait that times out prints a note and stops anyway, and the coordinator approved it.

## What happened

Spec 031 FR-5 says nothing in the proof is a warning that lets the job pass, except two named skips. The implementation review (Opus, read-only) found that the note-and-continue path was one: a build whose queue never starts would pass if Puma still exited 0 or 143. The fix raises a failure that names the missing processes and quotes the log. Both the proposal and the approval had not read FR-5.

## What to do next time

- Before proposing a "carry on after a timeout" path in a proof or a check, read the spec's rules on what may pass with a warning (here FR-5) and name the rule in the proposal.
- A fallback that exists for a hypothetical (another log format) is not worth a soft pass; every reachable input behaved the same.
