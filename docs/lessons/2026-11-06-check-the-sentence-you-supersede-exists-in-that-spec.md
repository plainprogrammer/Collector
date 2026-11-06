---
date: 2026-11-06
spec: "047"
tags: [specs, supersession, documentation]
---

# Lesson: Check that the sentence you supersede exists in the spec you cite

## Context

Spec 047 changes how the scanner's "Set" answers when it deletes an empty sitting: the status line, emptied before, now says a sentence. Its first draft recorded that as superseding "spec 040 AC-1.8 (the status)", in the spec's Supersedes table and in the index.

## What happened

Spec 040 never says the status line is cleared: its AC-1.8 only deletes the sitting. The clearing was behaviour that spec 042 decision 3 wrote down ("as spec 040 does"). The Fable spec review found it by reading spec 040. The citation would have pointed readers to a sentence that is not there, in both directions of the index.

## What to do next time

When a spec supersedes a line of an earlier spec, grep the cited spec for the quoted sentence before writing the row, and supersede it where it is written (here 042 decision 3), saying so in the cited spec's row if the behaviour was only implied. Check the code and the request specs for the same behaviour (`status_cleared?` was a helper in the spec 042 examples).

## Signals to watch for

- A supersession that quotes behaviour from the code or a request spec, not from the spec's text.
- A "as spec NNN does" in a later spec: the earlier one may never have stated it.
